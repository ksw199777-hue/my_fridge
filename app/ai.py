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
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
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
            "cooking_time": "조리시간(분)",
            "steps": [
                "1. 첫번째 단계",
                "2. 두번째 단계",
                "3. 세번째 단계"
            ]
        }}
    ]
}}
5가지 요리만 추천해주세요.
steps는 5단계 이내로 간단하게 작성해주세요."""
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

def chat_recipe(message: str, ingredient_names: str) -> dict:
    message_response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
        messages=[
            {
                "role": "user",
                 "content": f"""당신은 요리 전문가입니다. 오직 요리, 음식, 식재료 관련 질문만 답변하세요.
                요리와 관련없는 질문이 오면 {{"response": "저는 요리 관련 질문만 답변할 수 있어요! 🍳", "recipes": []}} 만 반환하세요.

                사용자의 냉장고에 있는 재료를 기반으로 요리를 추천해주세요.

현재 냉장고 재료: {ingredient_names}

사용자 요청: {message}

반드시 다음 JSON 형식으로만 답해주세요. 다른 텍스트는 절대 포함하지 마세요:
{{
    "response": "친근하고 자연스러운 답변 (2-3문장)",
    "recipes": [
        {{
            "name": "요리명",
            "ingredients_needed": ["재료1", "재료2"],
            "missing_ingredients": ["없는재료1"],
            "difficulty": "쉬움/보통/어려움",
            "cooking_time": "조리시간(분)",
            "steps": ["1. 단계1", "2. 단계2"]
        }}
    ]
}}
레시피가 필요없는 일반 대화면 recipes는 빈 배열로 반환해주세요.
JSON 외의 텍스트는 절대 포함하지 마세요."""
            }
        ],
    )
    
    import json
    import re
    
    response_text = message_response.content[0].text.strip()
    
    # JSON 부분만 추출
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        try:
            result = json.loads(json_match.group())
            return result
        except json.JSONDecodeError:
            pass
    
    # JSON 파싱 실패시 텍스트를 그대로 반환
    return {
        "response": response_text if response_text else "죄송해요, 다시 한번 말씀해주세요!",
        "recipes": []
    }

def estimate_price(items: list) -> dict:
    item_names = ", ".join([f"{item['name']} {item['quantity']}" for item in items])
    
    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": f"""다음 식재료들의 한국 마트 기준 평균 가격을 알려주세요.

식재료 목록: {item_names}

다음 JSON 형식으로만 답해주세요:
{{
    "items": [
        {{
            "name": "재료명",
            "quantity": "수량/무게",
            "unit_price": 개당평균가격(원),
            "total_price": 총가격(원)
        }}
    ],
    "total": 전체합계(원)
}}
가격은 숫자만 입력해주세요."""
            }
        ],
    )
    
    import json
    import re
    response_text = message.content[0].text
    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
    if json_match:
        return json.loads(json_match.group())
    return {"items": [], "total": 0}