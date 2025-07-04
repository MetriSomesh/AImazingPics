
from fastapi import APIRouter, HTTPException, Form
from typing import List
import replicate
import os
from dotenv import load_dotenv


load_dotenv()

router = APIRouter(prefix="/ai", tags=["AI"])

replicate_client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))

@router.post("/generate-multiple-images")
async def generate_multiple_images(
    prompts: str = Form(...),
    image_url: str = Form(...) 
):

    prompt_list = [prompt.strip() for prompt in prompts.split(',') if prompt.strip()]

    if not prompt_list or len(prompt_list) == 0:
        raise HTTPException(status_code=400, detail="At least one prompt is required.")

    if not image_url:
        raise HTTPException(status_code=400, detail="Image URL is required.")


    if not (image_url.startswith('http://') or image_url.startswith('https://')):
        raise HTTPException(status_code=400, detail="Image URL must be a valid HTTP or HTTPS URL.")

    generated_images = []

    try:
        for i, prompt in enumerate(prompt_list):
            try:
                output = replicate_client.run(
                    "black-forest-labs/flux-kontext-pro",
                    input={
                        "prompt": prompt,
                        "input_image": image_url,
                        "output_format": "jpg",
                        "aspect_ratio": "match_input_image",
                        "safety_tolerance": 2
                    }
                )

                image_url_result = None
                if hasattr(output, 'url'):
                    image_url_result = str(output.url)
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
                elif isinstance(output, str) and output.startswith('http'):
                    image_url_result = output
                else:
                    image_url_result = str(output)

                if image_url_result and image_url_result.startswith('http'):
                    generated_images.append({
                        "prompt": prompt,
                        "image_url": image_url_result
                    })
                    print(f"Generated URL: {image_url_result}")
                else:
                    error_msg = f"Invalid output for prompt: {prompt}"
                    print(error_msg)
                    generated_images.append({
                        "prompt": prompt,
                        "error": error_msg
                    })

            except Exception as prompt_error:
                error_msg = f"Error processing prompt '{prompt}': {str(prompt_error)}"
                print(error_msg)
                generated_images.append({
                    "prompt": prompt,
                    "error": error_msg
                })

        return {
            "total_prompts": len(prompt_list),
            "generated_images": generated_images
        }

    except Exception as e:
        print(f"General error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")