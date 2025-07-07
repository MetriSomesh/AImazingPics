from fastapi import APIRouter, HTTPException
from pydantic import BaseModel  # For data validation
from datetime import datetime, timedelta, timezone
import random  # For generating OTPs
from models.user import User  # Our database user model
import os
from dotenv import load_dotenv  # For environment variables
from twilio.rest import Client  # For SMS service

# Load environment variables from .env file
load_dotenv()

# Twilio SMS service credentials
TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN')
TWILIO_PHONE_NUMBER = os.getenv('TWILIO_PHONE_NUMBER')

# Initialize Twilio client
client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

# Create API router for authentication endpoints
router = APIRouter(prefix="/auth", tags=["Auth"])

# Data model for sending OTP request
class SendOtpRequest(BaseModel):
    phone: str  # User's phone number

# Data model for verifying OTP request
class VerifyOtpRequest(BaseModel):
    phone: str  # User's phone number
    otp: int    # The OTP code to verify

@router.post("/send-otp")
async def send_otp(request: SendOtpRequest):
    """
    Sends a 6-digit OTP to the user's phone number via SMS.
    The OTP is valid for 2 minutes.
    """
    phone = request.phone  # Get phone number from request

    # Generate a random 6-digit OTP
    otp = random.randint(100000, 999999)  # Between 100000 and 999999
    
    # Calculate expiration time (2 minutes from now)
    expiry_datetime_utc = datetime.now(timezone.utc) + timedelta(minutes=2)
    # Convert to Unix timestamp for easy comparison later
    expiry_unix_epoch = int(expiry_datetime_utc.timestamp())

    # Find user in database
    user = await User.find_one(User.mobile == phone)

    # If user doesn't exist, return error
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Format phone number for Twilio (ensure country code)
    formatted_phone = phone if phone.startswith('+') else f'+91{phone}'

    # Save OTP and expiration time to user record
    user.otp = otp
    user.otp_expiry = expiry_unix_epoch
    await user.save()

    try:
        # Send SMS with OTP using Twilio
        message = client.messages.create(
            body=f"Your AImazing verification code is: {otp}",  # SMS text
            from_=TWILIO_PHONE_NUMBER,  # Our Twilio phone number
            to=formatted_phone          # User's phone number
        )
        return {"message": "OTP sent successfully", "sid": message.sid}

    except Exception as e:
        # Handle SMS sending errors
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to send OTP: {str(e)}"
        )

@router.post("/verify-otp")
async def verify_otp(request: VerifyOtpRequest):
    """
    Verifies if the entered OTP matches what was sent to the user
    and checks if it's still valid (not expired).
    """
    phone = request.phone  # User's phone number
    otp = request.otp      # The OTP code they entered

    # Find user in database
    user = await User.find_one(User.mobile == phone)

    # Check if user exists
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Get current time as Unix timestamp
    current_unix_epoch = int(datetime.now(timezone.utc).timestamp())

    # Check if OTP was ever generated for this user
    if not user.otp or not user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP not generated for this user.")

    # Check if OTP has expired
    if current_unix_epoch > user.otp_expiry:
        raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")

    # Check if entered OTP matches what we sent
    if user.otp != otp:
        raise HTTPException(status_code=400, detail="Incorrect OTP. Please try again.")

    # If all checks pass, mark user as verified
    user.is_verified = True
    user.otp = None         # Clear used OTP
    user.otp_expiry = None  # Clear expiration time
    await user.save()

    return {"message": "Phone number verified successfully!"}