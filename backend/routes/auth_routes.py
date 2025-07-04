from fastapi import APIRouter, HTTPException
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel # Import BaseModel
from datetime import datetime, timedelta, timezone
import random
from models.user import User
import os
from dotenv import load_dotenv
from twilio.rest import Client

load_dotenv()

TWILIO_ACCOUNT_SID=os.getenv('TWILIO_ACCOUNT_SID')
TWILIO_AUTH_TOKEN=os.getenv('TWILIO_AUTH_TOKEN')
TWILIO_PHONE_NUMBER=os.getenv('TWILIO_PHONE_NUMBER')


client = Client(TWILIO_ACCOUNT_SID,TWILIO_AUTH_TOKEN)

router = APIRouter(prefix="/auth", tags=["Auth"])

class SendOtpRequest(BaseModel):
    phone: str

class VerifyOtpRequest(BaseModel):
    phone: str
    otp: int

@router.post("/send-otp")
async def send_otp(request: SendOtpRequest):
    phone = request.phone 

    otp = random.randint(100000,999999)
    expiry_datetime_utc = datetime.now(timezone.utc) + timedelta(minutes=2)
    expiry_unix_epoch = int(expiry_datetime_utc.timestamp())

    user = await User.find_one(User.mobile==phone)

 
    if not user:
        raise HTTPException(status_code=404,detail="User not found")

    formatted_phone = phone if phone.startswith('+') else f'+91{phone}'

    user.otp = otp
    user.otp_expiry = expiry_unix_epoch

    await user.save()

    try:
        message = client.messages.create(
            body=f"Your OTP is {otp}",
            from_= TWILIO_PHONE_NUMBER, 
            to=formatted_phone
        )
        return {"message":"OTP sent successfully","sid":message.sid}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error occurred while sending otp: {str(e)}")


@router.post("/verify-otp")
async def verify_otp(request: VerifyOtpRequest):
    phone = request.phone
    otp = request.otp    

   
    user = await User.find_one(User.mobile == phone)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    current_unix_epoch = int(datetime.now(timezone.utc).timestamp())

    
    if not user.otp or not user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP not generated for this user.")

    if current_unix_epoch > user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP has expired.")

    if user.otp != otp:
        raise HTTPException(status_code=400, detail="OTP is incorrect.")

    user.is_verified = True
    user.otp = None
    user.otp_expiry = None
    await user.save()

    return {"message": "Phone number verified successfully"}