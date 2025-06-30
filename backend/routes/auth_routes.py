from fastapi import APIRouter, HTTPException
from datetime import datetime, timedelta
import random
from models.user import User
import requests
import os
from dotenv import load_dotenv

load_dotenv()

SMS_URI = os.getenv("SMS_URI")
FAST2SMS_API_KEY = os.getenv("FAST2SMS_API_KEY")

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/send-otp")
async def send_otp(phone: str):
    otp = random.randint(100000, 999999)
    expiry = datetime.utcnow() + timedelta(minutes=2)

    user = await User.find_one(User.mobile == int(phone))

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.otp = otp
    user.otp_expiry = expiry
    await user.save()

    payload = {
        "variables_values": otp,
        "route": "otp",
        "numbers": phone
    }

    headers = {
        "authorization": FAST2SMS_API_KEY
    }

    try:
        response = requests.post(SMS_URI, data=payload, headers=headers)

        if response.status_code == 200:
            return {"message": "OTP sent successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to send OTP: " + response.text)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error occurred while sending OTP: {str(e)}")


@router.post("/verify-otp")
async def verify_otp(phone: str, otp: int):
    user = await User.find_one(User.mobile == int(phone))

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not user.otp or not user.otp_expiry or datetime.utcnow() > user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP expired or not generated")

    if user.otp != otp:
        raise HTTPException(status_code=400, detail="OTP is incorrect")

    user.is_verified = True
    user.otp = None
    user.otp_expiry = None
    await user.save()

    return {"message": "Phone number verified successfully"}
