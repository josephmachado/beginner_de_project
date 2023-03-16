def _vector_query(query_vec, category,vector_field, cosine=False):
    """
    Construct an Elasticsearch script score query using `dense_vector` fields
    
    The script score query takes as parameters the query vector (as a Python list)
    
    Parameters
    ----------
    query_vec : list
        The query vector
    vector_field : str
        The field name in the document against which to score `query_vec`
    q : str, optional
        Query string for the search query (default: '*' to search across all documents)
    cosine : bool, optional
        Whether to compute cosine similarity. If `False` then the dot product is computed (default: False)
     
    Note: Elasticsearch cannot rank negative scores. Therefore, in the case of the dot product, a sigmoid transform
    is applied. In the case of cosine similarity, 1.0 is added to the score. In both cases, documents with no 
    factor vectors are ignored by applying a 0.0 score.
    
    The query vector passed in will be the user factor vector (if generating recommended items for a user)
    or product factor vector (if generating similar items for a given item)
    """
    
    if cosine:
        score_fn = "doc['{v}'].size() == 0 ? 0 : cosineSimilarity(params.vector, '{v}') + 1.0"
    else:
        score_fn = "doc['{v}'].size() == 0 ? 0 : sigmoid(1, Math.E, -dotProduct(params.vector, '{v}'))"
       
    score_fn = score_fn.format(v=vector_field, fn=score_fn)
    
    return {
        "query": {
            "script_score": {
                "query" : { 
                    "bool" : {
                        "filter" : {
                                "term" : {
                                "main_category" : category
                                }
                            }
                    }
                },
                "script": {
                    "source": score_fn,
                    "params": {
                        "vector": query_vec
                    }
                }
            }
        }
    }


def get_recommendation(es, the_id, rec_num=10, index="products", vector_field='model_factor'):
    """
    Given a item id, execute the recommendation script score query to find similar items,
    ranked by cosine similarity. We return the `rec_num` most similar, excluding the item itself.
    """
    response = es.get(index=index, id=the_id)
    src = response['_source']
    if vector_field in src:
        query_vec = src[vector_field]
        category = src['main_category']
        q = _vector_query(query_vec, category,vector_field, cosine=True)
#         print(q)
        results = es.search(index=index, body=q)
        hits = results['hits']['hits']
        return src,hits[1:rec_num+1]
    else:
        return None, None