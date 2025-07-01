from fastapi import APIRouter, HTTPException
from datetime import datetime, timedelta
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

@router.post("/send-otp")
async def send_otp(phone:str):
    otp = random.randint(100000,999999)
    expiry = datetime.utcnow()+timedelta(minutes=5)

    user = await User.find_one(User.mobile==int(phone))

    if not user:
        raise HTTPException(status_code=404,detail="User not found")

    formatted_phone = phone if phone.startswith('+') else f'+91{phone}'

    user.otp = otp
    user.otp_expiry = expiry

    await user.save()

    try:
        message = client.messages.create(
            body=f"Your OTP is {otp}",
            from_= "+14126181631",
            to=formatted_phone
        )
        return {"message":"OTP sent successfully","sid":message.sid}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error occurred while sending otp: {str(e)}")


@router.post("/verify-otp")
async def verify_otp(phone:str, otp:int):
    user = await User.find_one(User.mobile == int(phone))

    if not user:
        raise HTTPException(status_code=404,detail="User not found")

    if not user.otp or not user.otp_expiry or datetime.utcnow() > user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP expired or not generated")
    
    if user.otp !=otp:
        raise HTTPException(status_code=400, detail="OTP is incorrect")
    
    user.is_verified = True
    user.otp = None
    user.otp_expiry = None
    await user.save()

    return {"message":"Phone number verified successfully"}