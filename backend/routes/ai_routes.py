


from fastapi import APIRouter, UploadFile, HTTPException, Form
from typing import List
import replicate
import os
from dotenv import load_dotenv
import shutil
import tempfile
import uuid

load_dotenv()

router = APIRouter(prefix="/ai", tags=["AI"])

replicate_client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))

@router.post("/generate-multiple-images")
async def generate_multiple_images(
    prompts: str = Form(...), 
    image: UploadFile = None
):
    
    prompt_list = [prompt.strip() for prompt in prompts.split(',') if prompt.strip()]
    

    if not prompt_list or len(prompt_list) == 0:
        raise HTTPException(status_code=400, detail="At least one prompt is required.")
    
   
    if image is None:
        raise HTTPException(status_code=400, detail="Image file is required.")
    
   
    if not image.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image.")
    
    temp_path = None
    try:
        
        temp_path = f"temp_{uuid.uuid4()}_{image.filename}"
        
       
        with open(temp_path, "wb") as buffer:
            content = await image.read()  
            buffer.write(content)
        
        generated_images = []
        
       
        for i, prompt in enumerate(prompt_list):
            # print(f"Processing prompt {i+1}/{len(prompt_list)}: {prompt}")
            
            try:
               
                with open(temp_path, "rb") as img_file:
                    output = replicate_client.run(
                        "black-forest-labs/flux-kontext-pro",
                        input={
                            "prompt": prompt,
                            "input_image": img_file,
                            "output_format": "jpg",
                            "aspect_ratio": "match_input_image",
                            "safety_tolerance": 2
                        }
                    )
                
               
                if hasattr(output, 'url'):
                
                    image_url = str(output.url)
                elif hasattr(output, '__iter__') and not isinstance(output, (str, bytes)):
                    
                    output_list = list(output)
                    if output_list:
                        result = output_list[0]
                        if hasattr(result, 'url'):
                            image_url = str(result.url)
                        elif isinstance(result, str) and result.startswith('http'):
                            image_url = result
                        else:
                            image_url = str(result)
                    else:
                        image_url = None
                elif isinstance(output, str) and output.startswith('http'):
                    image_url = output
                else:
                    image_url = str(output)
                
                if image_url and image_url.startswith('http'):
                    generated_images.append({
                        "prompt": prompt,
                        "image_url": image_url
                    })
                    print(f"Generated URL: {image_url}")
                else:
                    error_msg = f"Invalid output for prompt: {prompt}"
                    print(error_msg)
                    generated_images.append({
                        "prompt": prompt,
                        "error": error_msg
                    })
                        
            except Exception as prompt_error:
                error_msg = f"Error: {str(prompt_error)}"
                print(f"Error processing prompt '{prompt}': {error_msg}")
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
    
    finally:
       
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception as cleanup_error:
                print(f"Error cleaning up temp file: {cleanup_error}")

