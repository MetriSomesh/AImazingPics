# import base64
# import os
# from io import BytesIO
# from uuid import uuid4  # For generating unique filenames

# import boto3  # AWS SDK for Python
# from dotenv import load_dotenv  # For loading environment variables
# from fastapi import APIRouter, HTTPException, status  # Web framework components
# from pydantic import ValidationError  # For data validation errors
# from bson import ObjectId  # For working with MongoDB IDs
# from enum import Enum  # For creating choice options

# from models.user import User  # Our database user model
# from schemas.image_upload import ImageUploadRequest  # Data validation model

# # Load environment variables from .env file
# load_dotenv()

# # Create API router - groups related endpoints together
# router = APIRouter(prefix="/upload", tags=['S3 Upload'])

# # Get AWS credentials from environment variables
# AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
# AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
# AWS_S3_BUCKET = os.getenv('AWS_S3_BUCKET')
# AWS_REGION = os.getenv('AWS_REGION')

# # Define possible image types (like dropdown options)
# class ImageType(str, Enum):
#     INPUT = "input"    # User's original photo
#     OUTPUT = "output"  # AI-generated image

# # Connect to AWS S3 service using our credentials
# s3_client = boto3.client(
#     "s3",
#     aws_access_key_id=AWS_ACCESS_KEY_ID,
#     aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
#     region_name=AWS_REGION
# )

# # Helper function to actually upload to S3
# async def _upload_image_to_s3(request: ImageUploadRequest):
#     """
#     Takes image data, uploads to S3, and returns a shareable link
#     """
#     try:
#         # Convert base64 string back to binary image data
#         image_bytes = base64.b64decode(request.file_content)
#     except Exception:
#         # Handle invalid image data
#         raise HTTPException(status_code=400, detail="Invalid Base64 image content.")

#     # Create a file-like object from binary data
#     file_obj = BytesIO(image_bytes)

#     # Clean up file extension (remove dot if present)
#     file_ext = request.file_extension.lower().replace('.', '')
#     if not file_ext:
#         raise HTTPException(status_code=400, detail="File extension is required.")

#     # Create unique filename using UUID
#     unique_filename = f"{uuid4()}.{file_ext}"

#     try:
#         # Upload to S3 bucket
#         s3_client.upload_fileobj(
#             file_obj,  # Our image data
#             AWS_S3_BUCKET,  # Target bucket name
#             unique_filename,  # Filename to save as
#             ExtraArgs={
#                 "ContentType": request.content_type,  # Like 'image/jpeg'
#             }
#         )
#     except Exception as e:
#         # Handle upload errors
#         raise HTTPException(status_code=500, detail=f"Failed to upload to S3: {str(e)}")

#     # Generate URL that expires in 24 hours
#     EXPIRES_IN_SECONDS = 24 * 60 * 60  # 24 hours in seconds

#     try:
#         # Create temporary access URL
#         presigned_url = s3_client.generate_presigned_url(
#             ClientMethod='get_object',  # We want to download the file
#             Params={
#                 'Bucket': AWS_S3_BUCKET,
#                 'Key': unique_filename
#             },
#             ExpiresIn=EXPIRES_IN_SECONDS  # URL lasts 24 hours
#         )
#     except Exception as e:
#         # Handle URL generation errors
#         raise HTTPException(status_code=500, detail=f"Failed to generate presigned URL: {str(e)}")

#     return presigned_url, unique_filename

# # Main API endpoint for image uploads
# @router.post("/image")
# async def upload_image_route(
#     request_data: ImageUploadRequest,  # Validated image data
#     image_type: ImageType = ImageType.INPUT  # Default to input image
# ):
#     """
#     Handles both input (selfie) and output (AI) image uploads:
#     1. Validates user ID
#     2. Uploads image to S3
#     3. Updates user record in database
#     4. Returns URL and info
#     """
#     try:
#         # Check if user ID format is valid
#         if not ObjectId.is_valid(request_data.user_id):
#             raise HTTPException(status_code=400, detail="Invalid User ID format.")

#         # Step 1: Upload to S3 and get URL
#         public_url, unique_filename = await _upload_image_to_s3(request_data)

#         # Step 2: Find user in database
#         user = await User.find_one(User.id == ObjectId(request_data.user_id))
#         if not user:
#             raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

#         # Step 3: Update correct field based on image type
#         if image_type == ImageType.INPUT:
#             user.input_img = public_url  # Save selfie URL
#         else:
#             user.output_img = public_url  # Save AI image URL

#         # Save updated user to database
#         await user.save()

#         # Step 4: Return success info
#         return {
#             "public_url": public_url,  # Temporary access URL
#             "s3_key": unique_filename,  # Filename in S3
#             "image_type": image_type.value  # 'input' or 'output'
#         }

#     # Error handling section:
#     except ValidationError as e:
#         # Handle data validation errors
#         raise HTTPException(status_code=422, detail=e.errors())
#     except HTTPException as e:
#         # Re-raise existing HTTP errors
#         raise e
#     except Exception as e:
#         # Catch-all for unexpected errors
#         raise HTTPException(
#             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
#             detail=f"An unexpected error occurred: {str(e)}"
#         )

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

# --- DEBUGGING ENVIRONMENT VARIABLES ---
print(f"DEBUG: AWS_ACCESS_KEY_ID loaded: {'Yes' if AWS_ACCESS_KEY_ID else 'No'}")
print(f"DEBUG: AWS_SECRET_ACCESS_KEY loaded: {'Yes' if AWS_SECRET_ACCESS_KEY else 'No'}")
print(f"DEBUG: AWS_S3_BUCKET: {AWS_S3_BUCKET}")
print(f"DEBUG: AWS_REGION: {AWS_REGION}")
# --- END DEBUGGING ENVIRONMENT VARIABLES ---

# Connect to AWS S3 service using our credentials
try:
    s3_client = boto3.client(
        "s3",
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION
    )
    print("DEBUG: S3 client initialized successfully.")
except Exception as e:
    print(f"ERROR: Failed to initialize S3 client: {str(e)}")
    raise Exception(f"Failed to initialize S3 client: {str(e)}")

# Helper function to actually upload to S3
async def _upload_image_to_s3(request: ImageUploadRequest):
    print(f"DEBUG: _upload_image_to_s3 called for user_id: {request.user_id}")
    print(f"DEBUG: Incoming file_extension: {request.file_extension}, content_type: {request.content_type}")
    print(f"DEBUG: file_content length (base64): {len(request.file_content) if request.file_content else 0}")

    try:
        image_bytes = base64.b64decode(request.file_content)
        print(f"DEBUG: Base64 decoded successfully. Image bytes length: {len(image_bytes)}")
    except Exception as e:
        print(f"ERROR: Failed to decode Base64 image content: {str(e)}")
        raise HTTPException(status_code=400, detail="Invalid Base64 image content.")

    file_obj = BytesIO(image_bytes)

    file_ext = request.file_extension.lower().replace('.', '')
    if not file_ext:
        print("ERROR: File extension is empty after cleanup.")
        raise HTTPException(status_code=400, detail="File extension is required.")
    print(f"DEBUG: Cleaned file extension: {file_ext}")

    unique_filename = f"{uuid4()}.{file_ext}"
    print(f"DEBUG: Generated unique filename: {unique_filename}")

    try:
        print(f"DEBUG: Attempting S3 upload to bucket: {AWS_S3_BUCKET}, key: {unique_filename}, ContentType: {request.content_type}")
        s3_client.upload_fileobj(
            file_obj,
            AWS_S3_BUCKET,
            unique_filename,
            ExtraArgs={
                "ContentType": request.content_type,
            }
        )
        print(f"DEBUG: S3 upload successful for {unique_filename}")
    except Exception as e:
        print(f"ERROR: Failed to upload to S3: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to upload to S3: {str(e)}")

    EXPIRES_IN_SECONDS = 24 * 60 * 60
    print(f"DEBUG: Generating presigned URL, expires in {EXPIRES_IN_SECONDS} seconds.")

    try:
        presigned_url = s3_client.generate_presigned_url(
            ClientMethod='get_object',
            Params={
                'Bucket': AWS_S3_BUCKET,
                'Key': unique_filename
            },
            ExpiresIn=EXPIRES_IN_SECONDS
        )
        print(f"DEBUG: Presigned URL generated successfully: {presigned_url[:50]}...")
    except Exception as e:
        print(f"ERROR: Failed to generate presigned URL: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to generate presigned URL: {str(e)}")

    return presigned_url, unique_filename

# Main API endpoint for image uploads (S3 and DB)
@router.post("/image")
async def upload_image_route(
    request_data: ImageUploadRequest
    # image_type parameter removed
):
    print(f"\n--- API Call: /upload/image (S3 and DB save) ---")
    print(f"DEBUG: Received request for user_id: {request_data.user_id}")

    try:
        # Check if user ID format is valid
        if not ObjectId.is_valid(request_data.user_id):
            print(f"ERROR: Invalid User ID format: {request_data.user_id}")
            raise HTTPException(status_code=400, detail="Invalid User ID format.")
        print(f"DEBUG: User ID format is valid: {request_data.user_id}")

        # Step 1: Upload to S3 and get URL
        print("DEBUG: Calling _upload_image_to_s3...")
        public_url, unique_filename = await _upload_image_to_s3(request_data)
        print(f"DEBUG: Image upload to S3 completed. URL: {public_url[:50]}..., S3 Key: {unique_filename}")

        # Step 2: Find user in database
        print(f"DEBUG: Attempting to find user with ID: {request_data.user_id}")
        user = await User.find_one(User.id == ObjectId(request_data.user_id))
        if not user:
            print(f"ERROR: User not found with ID: {request_data.user_id}")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
        print(f"DEBUG: User found: {user.id}")

        # Step 3: Update the input_img field (as there's no type distinction now)
        user.input_img = public_url
        print(f"DEBUG: Updating user's input_img field to: {public_url[:50]}...")

        # Save updated user to database
        await user.save()
        print("DEBUG: User record updated successfully in database.")

        # Step 4: Return success info
        print("DEBUG: Image upload route completed successfully (S3 and DB save).")
        return {
            "public_url": public_url,
            "s3_key": unique_filename,
            "message": "Image uploaded to S3 and user record updated successfully."
        }

    # Error handling section:
    except ValidationError as e:
        print(f"ERROR: Data validation error: {e.errors()}")
        raise HTTPException(status_code=422, detail=e.errors())
    except HTTPException as e:
        print(f"ERROR: HTTP Exception caught: Status Code {e.status_code}, Detail: {e.detail}")
        raise e
    except Exception as e:
        print(f"CRITICAL ERROR: An unexpected error occurred in upload_image_route: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {str(e)}"
        )