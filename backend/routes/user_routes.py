from bson import ObjectId
from fastapi import APIRouter
from models.user import User

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/create")
async def create_user(user: User):
    await user.insert()
    return user



@router.post("/update")
async def update_user(userid:str, updated_img:str):

    user  = await User.find_one(User.id == ObjectId(userid))

    if not user:
        return {"Message":"User not found"}
    
    user.output_img = updated_img

    await user.save

    return {"message":"Image updated"}
