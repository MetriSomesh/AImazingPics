from fastapi import APIRouter, HTTPException, Form
from typing import List
import replicate
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Create a router for AI-related endpoints
router = APIRouter(prefix="/ai", tags=["AI"])

# Initialize the Replicate client with our API key
replicate_client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))

@router.post("/generate-multiple-images")
async def generate_multiple_images(
    prompts: str = Form(...),  # Comma-separated list of prompts
    image_url: str = Form(...)  # URL of the input image
):
    """
    Generates multiple AI images from a single input image using different prompts.
    Takes a comma-separated list of prompts and one image URL.
    Returns a collection of generated images with their corresponding prompts.
    """
    
    # Split the comma-separated prompts into a list and clean them up
    prompt_list = [prompt.strip() for prompt in prompts.split(',') if prompt.strip()]

    # Validate we have at least one prompt
    if not prompt_list or len(prompt_list) == 0:
        raise HTTPException(status_code=400, detail="At least one prompt is required.")

    # Validate we have an image URL
    if not image_url:
        raise HTTPException(status_code=400, detail="Image URL is required.")

    # Validate the image URL format
    if not (image_url.startswith('http://') or image_url.startswith('https://')):
        raise HTTPException(status_code=400, detail="Image URL must be a valid HTTP or HTTPS URL.")

    # This will store all our generated images
    generated_images = []

    try:
        # Process each prompt one by one
        for i, prompt in enumerate(prompt_list):
            try:
                print(f"Processing prompt {i+1}/{len(prompt_list)}: {prompt}")
                
                # Call the Replicate API to generate an image
                output = replicate_client.run(
                    "black-forest-labs/flux-kontext-pro",  # The AI model we're using
                    input={
                        "prompt": prompt,  # The text description for image generation
                        "input_image": image_url,  # The image to transform
                        "output_format": "jpg",  # We want JPEG output
                        "aspect_ratio": "match_input_image",  # Keep original proportions
                        "safety_tolerance": 2  # How strict the content filter should be
                    }
                )

                # The API might return different response formats, so we need to handle various cases
                image_url_result = None
                
                # Case 1: Output has a direct URL attribute
                if hasattr(output, 'url'):
                    image_url_result = str(output.url)
                
                # Case 2: Output is an iterable (like a list)
                elif hasattr(output, '__iter__') and not isinstance(output, (str, bytes)):
                    output_list = list(output)
                    if output_list:
                        result = output_list[0]
                        if hasattr(result, 'url'):
                            image_url_result = str(result.url)
                        elif isinstance(result, str) and result.startswith('http'):
                            image_url_result = result
                        else:
                            image_url_result = str(result)
                
                # Case 3: Output is a direct URL string
                elif isinstance(output, str) and output.startswith('http'):
                    image_url_result = output
                
                # Fallback: Convert whatever we got to string
                else:
                    image_url_result = str(output)

                # If we got a valid URL, add it to our results
                if image_url_result and image_url_result.startswith('http'):
                    generated_images.append({
                        "prompt": prompt,
                        "image_url": image_url_result
                    })
                    print(f"Successfully generated image for prompt: {prompt}")
                
                # If the output wasn't a valid URL, record an error
                else:
                    error_msg = f"AI model returned unexpected output for prompt: {prompt}"
                    print(error_msg)
                    generated_images.append({
                        "prompt": prompt,
                        "error": error_msg
                    })

            # Handle errors for individual prompts (so one failure doesn't stop the whole batch)
            except Exception as prompt_error:
                error_msg = f"Failed to process prompt '{prompt}': {str(prompt_error)}"
                print(error_msg)
                generated_images.append({
                    "prompt": prompt,
                    "error": error_msg
                })

        # Return our collection of results
        return {
            "total_prompts": len(prompt_list),  # How many prompts we processed
            "generated_images": generated_images  # The actual results
        }

    # Handle any unexpected errors that affect the entire process
    except Exception as e:
        print(f"Something went terribly wrong: {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"We hit a snag while generating your images. Please try again later."
        )