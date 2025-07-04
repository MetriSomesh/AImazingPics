from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware # Import CORSMiddleware
from db import init_db
from routes.user_routes import router as user_router
from routes.auth_routes import router as auth_router
from routes.ai_routes import router as ai_routes
from routes.s3_bucket_routes import router as s3_bucket_routes

app = FastAPI()

origins = [
    "http://localhost",
    "http://localhost:8080",  
    "http://127.0.0.1:8000",  
    "http://10.0.2.2:8000",  
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"], 
    allow_headers=["*"], 
)



@app.on_event("startup")
async def start_db():
    await init_db()

app.include_router(user_router)
app.include_router(auth_router)
app.include_router(ai_routes)
app.include_router(s3_bucket_routes)