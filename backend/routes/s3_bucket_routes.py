
import base64
import os
from io import BytesIO
from uuid import uuid4

import boto3
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, status
from pydantic import ValidationError
from bson import ObjectId  # Re-introducing for MongoDB ID validation
# from enum import Enum # Removed as per request

from models.user import User  # Re-introducing for database interaction
from schemas.image_upload import ImageUploadRequest

# Load environment variables from .env file
load_dotenv()

# Create API router - groups related endpoints together
router = APIRouter(prefix="/upload", tags=['S3 Upload'])

# Get AWS credentials from environment variables
AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
AWS_S3_BUCKET = os.getenv('AWS_S3_BUCKET')
AWS_REGION = os.getenv('AWS_REGION')

# Connect to AWS S3 service using our credentials
try:
    s3_client = boto3.client(
        "s3",
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION
    )
   
except Exception as e:
   
    raise Exception(f"Failed to initialize S3 client: {str(e)}")

# Helper function to actually upload to S3
async def _upload_image_to_s3(request: ImageUploadRequest):

    try:
        image_bytes = base64.b64decode(request.file_content)
      
    except Exception as e:
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

# Main API endpoint for image uploads (S3 and DB)
@router.post("/image")
async def upload_image_route(
    request_data: ImageUploadRequest
):

    try:
        # Check if user ID format is valid
        if not ObjectId.is_valid(request_data.user_id):
        
            raise HTTPException(status_code=400, detail="Invalid User ID format.")
        

        # Step 1: Upload to S3 and get URL
        public_url, unique_filename = await _upload_image_to_s3(request_data)
       
        # Step 2: Find user in database
     
        image_type = request_data.image_type
        user = await User.find_one(User.id == ObjectId(request_data.user_id))
        if not user:
         
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
        

        # Step 3: Update the input_img field (as there's no type distinction now)
        if image_type == 'input':
            user.input_img = public_url
        else:
            user.output_img = public_url

        # Save updated user to database
        await user.save()
       

        # Step 4: Return success info
       
        return {
            "public_url": public_url,
            "s3_key": unique_filename,
            "message": "Image uploaded to S3 and user record updated successfully."
        }

    # Error handling section:
    except ValidationError as e:
    
        raise HTTPException(status_code=422, detail=e.errors())
    except HTTPException as e:
        
        raise e
    except Exception as e:
      
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {str(e)}"
        )