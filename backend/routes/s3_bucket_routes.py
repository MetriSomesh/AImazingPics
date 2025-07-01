
from bson import ObjectId
from fastapi import APIRouter, UploadFile, File, HTTPException

import boto3
import os
from dotenv import load_dotenv
from uuid import uuid4
from models.user import User

load_dotenv()

router = APIRouter(prefix="/upload",tags=['S3 Upload'])

AWS_ACCESS_KEY_ID=os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
AWS_S3_BUCKET=os.getenv('AWS_S3_BUCKET')
AWS_REGION=os.getenv('AWS_REGION')


s3_client = boto3.client(
    "s3",
    aws_access_key_id = AWS_ACCESS_KEY_ID,
    aws_secret_access_key = AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION
)

@router.post("/input_image")
async def upload_input_image(file:UploadFile , user_id:str):

    try:
        file_ext = file.filename.split(".")[-1]
        unique_filename = f"{uuid4()}.{file_ext}"

        s3_client.upload_fileobj(
            file.file,
            AWS_S3_BUCKET,
            unique_filename,
            ExtraArgs={
                "ContentType":file.content_type,

            }
        )

        public_url = f"https://{AWS_S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{unique_filename}"

        user = await User.find_one(User.id == ObjectId(user_id))

        if not user:
            return {"message":"User not present"}
        
        user.input_img = public_url

        await user.save()

        return {"public_url":public_url,"s3_key":unique_filename}
       
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    

@router.post("/output_image")
async def upload_output_image(file:UploadFile , user_id:str):

    try:
        file_ext = file.filename.split(".")[-1]
        unique_filename = f"{uuid4()}.{file_ext}"

        s3_client.upload_fileobj(
            file.file,
            AWS_S3_BUCKET,
            unique_filename,
            ExtraArgs={
                "ContentType":file.content_type,
                
            }
        )

        public_url = f"https://{AWS_S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{unique_filename}"

        user = await User.find_one(User.id == ObjectId(user_id))

        if not user:
            return {"message":"User not present"}
        
        user.output_img = public_url

        await user.save()

        return {"public_url":public_url,"s3_key":unique_filename}
       
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    