import base64
import os
from io import BytesIO
from uuid import uuid4

import boto3
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, status
from pydantic import ValidationError
from bson import ObjectId
from typing import Annotated

from models.user import User
from schemas.image_upload import ImageUploadRequest


load_dotenv()

router = APIRouter(prefix="/upload", tags=['S3 Upload'])

AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
AWS_S3_BUCKET = os.getenv('AWS_S3_BUCKET')
AWS_REGION = os.getenv('AWS_REGION')


s3_client = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION
)

async def _upload_image_to_s3(request: ImageUploadRequest):
    """
    Helper function to handle the S3 upload logic.
    Decodes base64 content and uploads to S3.
    Generates a presigned URL with a 24-hour expiry.
    """
    try:
        image_bytes = base64.b64decode(request.file_content)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Base64 image content.")

    file_obj = BytesIO(image_bytes)

    file_ext = request.file_extension.lower().replace('.', '')
    if not file_ext:
        raise HTTPException(status_code=400, detail="File extension is required.")

    unique_filename = f"{uuid4()}.{file_ext}"

    try:
        s3_client.upload_fileobj(
            file_obj,
            AWS_S3_BUCKET,
            unique_filename,
            ExtraArgs={
                "ContentType": request.content_type,
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to upload to S3: {str(e)}")

  
    EXPIRES_IN_SECONDS = 24 * 60 * 60

    try:
        presigned_url = s3_client.generate_presigned_url(
            ClientMethod='get_object',
            Params={
                'Bucket': AWS_S3_BUCKET,
                'Key': unique_filename
            },
            ExpiresIn=EXPIRES_IN_SECONDS
        )
    except Exception as e:
       
        raise HTTPException(status_code=500, detail=f"Failed to generate presigned URL: {str(e)}")
 

    return presigned_url, unique_filename

@router.post("/input_image")
async def upload_input_image_route(request_data: ImageUploadRequest):
    try:
        if not ObjectId.is_valid(request_data.user_id):
            raise HTTPException(status_code=400, detail="Invalid User ID format.")

       
        public_url, unique_filename = await _upload_image_to_s3(request_data)

        user = await User.find_one(User.id == ObjectId(request_data.user_id))

        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

        user.input_img = public_url 
        await user.save()

        return {"public_url": public_url, "s3_key": unique_filename}

    except ValidationError as e:
        raise HTTPException(status_code=422, detail=e.errors())
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {str(e)}")


@router.post("/output_image")
async def upload_output_image_route(request_data: ImageUploadRequest):
    try:
        if not ObjectId.is_valid(request_data.user_id):
            raise HTTPException(status_code=400, detail="Invalid User ID format.")

        
        public_url, unique_filename = await _upload_image_to_s3(request_data)

        user = await User.find_one(User.id == ObjectId(request_data.user_id))

        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

        user.output_img = public_url 
        await user.save()

        return {"public_url": public_url, "s3_key": unique_filename}

    except ValidationError as e:
        raise HTTPException(status_code=422, detail=e.errors())
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {str(e)}")