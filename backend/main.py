# from fastapi import FastAPI
# from pydantic import BaseModel
# from typing import List


# app = FastAPI()

# class Student(BaseModel):
#     id:int
#     name:str
#     origin:str


# records:List[Student] =[]

# @app.get('/')
# def read_root():
#     return {"Message":"Welcome to Students Records"}

# @app.get('/records')
# def get_records():
#     return records

# @app.post('/add')
# def add_record(record:Student):
#     records.append(record)
#     return record

# @app.put('/records/{stud_id}')
# def update_record(stud_id:int, updated_record:Student):
#     for index, record in enumerate(records):
#         if record.id==stud_id:
#             records[index]  =updated_record
#             return updated_record
#     return {"error":"Record not found"}

# @app.delete('/records/{stud_id}')
# def delete_record(stud_id:int):
#     for index, record in enumerate(records):
#         if record.id == stud_id:
#            deleted =  records.pop(index)
#            return deleted
#     return {"error":"Record not found"}

from fastapi import FastAPI
from db import init_db
from routes.user_routes import router as user_router
from routes.auth_routes import router as auth_router
from routes.ai_routes import router as ai_routes
from routes.s3_bucket_routes import router as s3_bucket_routes

app = FastAPI()

@app.on_event("startup")
async def start_db():
    await init_db()

app.include_router(user_router)
app.include_router(auth_router)
app.include_router(ai_routes)
app.include_router(s3_bucket_routes)