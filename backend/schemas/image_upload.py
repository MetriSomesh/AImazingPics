# schemas/image_upload.py
from pydantic import BaseModel

class ImageUploadRequest(BaseModel):
    user_id: str
    file_content: str 
    content_type: str  
    file_extension: str
    image_type: str 