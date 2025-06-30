from fastapi import APIRouter, UploadFile, Form, HTTPException
import replicate
import os
from dotenv import load_dotenv

load_dotenv()

router = APIRouter(prefix="/ai", tags=["AI"])

replicate_client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))

@router.post("/generate-images")
async def generate_images(prompt: str = Form(...), image: str = ""):
    """
    Accepts a prompt and an image file.
    Returns AI-generated image(s) based on the prompt and image.
    """

    if image is None:
        raise HTTPException(status_code=400, detail="Image file is required")

    try:
       
        temp_path = f"temp_{image.filename}"
        with open(temp_path, "wb") as buffer:
            buffer.write(await image.read())

        
        with open(temp_path, "rb") as img_file:
            output = replicate_client.run(
                "stability-ai/stable-diffusion-img2img",
                input={
                    "image": img_file,
                    "prompt": prompt,
                    "strength": 0.75
                }
            )

        # Cleanup
        os.remove(temp_path)

        return {"generated_images": output}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
