import os
from fastapi import FastAPI
from models import RecommendRequest

from elasticsearch import Elasticsearch
from utils import get_recommendation

ES_HOST = os.env['ES_HOST']
ES_PORT = os.env['ES_PORT']
app = FastAPI()

def get_es():
    endpoint = f'http://{ES_HOST}:{ES_PORT}'
    es = Elasticsearch(endpoint)
    return es

@app.post("/recommend_product")
def recommend_product(recommend_request: RecommendRequest):
    es = get_es()
    product, recs = get_recommendation(es, recommend_request.id, num=recommend_request.rec_num, index='products')
    recommendations = []
    for rec in recs:
        r = {}
        r['asin'] = rec['_source']['asin']
        r['title'] = rec['_source']['title']
        r['score'] = rec['_score']
        recommendations.append(r)
    return recommendations

