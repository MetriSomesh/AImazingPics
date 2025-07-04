from beanie import Document
from typing import Optional
from datetime import datetime

class User(Document):
    name: str
    mobile:str
    diaplay_name:str
    input_img:Optional[str] = None
    output_img:Optional[str] = None
    otp: Optional[int] = None
    otp_expiry: Optional[int] = None
    is_verified: bool = False