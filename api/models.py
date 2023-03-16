from pydantic import BaseModel

class RecommendRequest(BaseModel):
    id: str
    rec_num: int
