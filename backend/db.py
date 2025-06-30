
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
from models.user import User
import os
from dotenv import load_dotenv

load_dotenv()
MONGO_URI = os.getenv('MONGO_URI')

client = AsyncIOMotorClient(MONGO_URI)
db = client['task1']

async def init_db():
    await init_beanie(database=db,document_models=[User])