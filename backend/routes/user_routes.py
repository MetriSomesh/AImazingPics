from fastapi import APIRouter
from models.user import User

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/create")
async def create_user(user: User):
    await user.insert()
    return user



@router.post("/upload_img")
async def upload_image(user_id:int, img:str):

    user  = await User.find_one(User._id == user_id)

    if not user:
        return {"message":"User not found"}

    user.output_img = img

    await user.save()

    return {"message":"Image uploaded successfully"}


@router.post("/update")
async def update_user(userid:int, updated_img:str):

    user  = await User.find_one(User._id == userid)

    if not user:
        return {"Message":"User not found"}
    
    user.output_img = updated_img

    await user.save

    return {"message":"Image updated"}
