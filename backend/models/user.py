from beanie import Document
from typing import Optional
from datetime import datetime

class User(Document):
    name: str
    mobile:int
    email: str
    diaplay_name:str
    input_img:Optional[str] = None
    output_img:Optional[str] = None
    otp: Optional[int] = None
    otp_expiry: Optional[datetime] = None
    is_verified: bool = False