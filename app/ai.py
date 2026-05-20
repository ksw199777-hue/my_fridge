import anthropic
import base64
import os

client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

def recognize_ingredients(image_bytes: bytes) -> list:
    # 이미지를 base64로 변환
    image_base64 = base64.standard_b64encode(image_bytes).decode("utf-8")
    
    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": image_base64,
                        },
                    },
                    {
                        "type": "text",
                        "text": """이 사진에서 식재료를 인식해주세요.
                        다음 JSON 형식으로만 답해주세요:
                        {
                            "ingredients": [
                                {"name": "재료명", "expiry_days": 유통기한(일수)}
                            ]
                        }
                        유통기한을 알수없는 경우 일반적인 보관 기간을 기준으로 추정해주세요."""
                    }
                ],
            }
        ],
    )
    
    import json
    import re
    
    response_text = message.content[0].text
    
    # JSON 부분만 추출
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        result = json.loads(json_match.group())
        return result["ingredients"]
    
    return []