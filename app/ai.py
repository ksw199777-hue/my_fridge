import anthropic
import base64
import os

client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

FOOD_FILTER = """
식재료 판단 기준:
- 포함: 채소, 과일, 육류, 해산물, 유제품, 계란, 곡물, 양념/소스, 음료
- 제외: 생활용품, 전자제품, 의류, 화장품, 문구류, 가구, 잡화 등
"""

def recognize_ingredients(image_bytes: bytes) -> list:
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
                        "text": f"""이 사진에서 식재료를 인식해주세요.
{FOOD_FILTER}
다음 JSON 형식으로만 답해주세요:
{{
    "ingredients": [
        {{
            "name": "재료명",
            "expiry_days": 유통기한(일수, 표시없으면 null),
            "consume_days": 소비기한(일수),
            "has_expiry_label": true/false
        }}
    ]
}}
- expiry_days: 제품에 유통기한 표시가 있으면 일수, 없으면 null
- consume_days: 오늘부터 안전하게 소비 가능한 일수 (냉장보관 기준)
- has_expiry_label: 유통기한 표시가 있으면 true, 없으면 false
식재료가 아닌 것은 반드시 제외해주세요."""
                    }
                ],
            }
        ],
    )
    
    import json
    import re
    response_text = message.content[0].text
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        result = json.loads(json_match.group())
        return result["ingredients"]
    return []

def recommend_recipes(ingredients: list) -> list:
    ingredient_names = ", ".join([i.name for i in ingredients])
    
    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": f"""다음 재료들로 만들 수 있는 요리를 추천해주세요.
재료: {ingredient_names}

다음 JSON 형식으로만 답해주세요:
{{
    "recipes": [
        {{
            "name": "요리명",
            "ingredients_needed": ["필요재료1", "필요재료2"],
            "missing_ingredients": ["없는재료1"],
            "difficulty": "쉬움/보통/어려움",
            "cooking_time": "조리시간(분)"
        }}
    ]
}}
5가지 요리만 추천해주세요."""
            }
        ],
    )
    
    import json
    import re
    response_text = message.content[0].text
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        result = json.loads(json_match.group())
        return result["recipes"]
    return []

def recognize_from_screenshot(image_bytes: bytes) -> list:
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
                        "text": f"""이것은 온라인 쇼핑몰 주문 내역 스크린샷입니다.
주문한 식재료 목록만 찾아주세요.
{FOOD_FILTER}
다음 JSON 형식으로만 답해주세요:
{{
    "ingredients": [
        {{
            "name": "재료명",
            "quantity": 수량,
            "expiry_days": 유통기한(일수, 확인불가면 null),
            "consume_days": 소비기한(일수),
            "has_expiry_label": false,
            "price": 가격
        }}
    ]
}}
- 스크린샷에서는 유통기한 확인이 불가하므로 has_expiry_label은 항상 false
- consume_days: 냉장보관 기준 안전하게 소비 가능한 일수
식재료가 아닌 상품은 반드시 제외해주세요."""
                    }
                ],
            }
        ],
    )
    
    import json
    import re
    response_text = message.content[0].text
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        result = json.loads(json_match.group())
        return result["ingredients"]
    return []

def recognize_expiry_date(image_bytes: bytes) -> dict:
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
                        "text": """이 사진에서 유통기한 또는 소비기한 날짜를 찾아주세요.

다음 JSON 형식으로만 답해주세요:
{
    "expiry_date": "YYYY-MM-DD",
    "found": true
}
날짜를 찾을 수 없으면:
{
    "expiry_date": null,
    "found": false
}"""
                    }
                ],
            }
        ],
    )
    
    import json
    import re
    response_text = message.content[0].text
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        return json.loads(json_match.group())
    return {"expiry_date": None, "found": False}

def recognize_receipt(image_bytes: bytes) -> list:
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
                        "text": f"""이것은 마트 영수증입니다.
식재료 목록과 가격만 찾아주세요.
{FOOD_FILTER}
다음 JSON 형식으로만 답해주세요:
{{
    "ingredients": [
        {{
            "name": "재료명",
            "price": 가격(숫자),
            "quantity": 수량(숫자),
            "expiry_days": 유통기한(일수, 확인불가면 null),
            "consume_days": 소비기한(일수),
            "has_expiry_label": false
        }}
    ]
}}
- 영수증에서는 유통기한 확인이 불가하므로 has_expiry_label은 항상 false
- consume_days: 냉장보관 기준 안전하게 소비 가능한 일수
식재료가 아닌 상품은 반드시 제외해주세요.
가격은 숫자만 입력해주세요."""
                    }
                ],
            }
        ],
    )
    
    import json
    import re
    response_text = message.content[0].text
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        result = json.loads(json_match.group())
        return result["ingredients"]
    return []