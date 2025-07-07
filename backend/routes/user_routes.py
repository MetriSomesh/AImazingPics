# Import required modules
from bson import ObjectId  # For working with MongoDB ObjectIDs
from fastapi import APIRouter  # For creating API routes
from models.user import User  # Our User model

# Create a router for user-related endpoints with prefix '/users'
# and tag for API documentation grouping
router = APIRouter(prefix="/users", tags=["Users"])

# Endpoint to create a new user
@router.post("/create")
async def create_user(user: User):
    # Save the new user to the database
    await user.insert()
    
    # Convert the user's MongoDB ID and phone number to strings
    user_id = str(user.id)
    phone_number = str(user.mobile)
    
    # Return the created user's ID and phone number
    return {"user_id": user_id, "phone_number": phone_number}

# Endpoint to update a user's image
@router.post("/update")
async def update_user(userid: str, updated_img: str):
    # Find the user in database using their ID
    user = await User.find_one(User.id == ObjectId(userid))
    
    # If user doesn't exist, return error message
    if not user:
        return {"Message": "User not found"}
    
    # Update the user's output image with the new one
    user.output_img = updated_img
    
    # Save the changes to database
    await user.save
    
    # Return success message
    return {"message": "Image updated"}