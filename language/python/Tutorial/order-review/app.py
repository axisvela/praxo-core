import argparse
import asyncio
import http.client
import json
import os
from urllib.parse import urlsplit

from praxo.agent import Agent, AgentOptions, Session
from praxo.adapters.openaicompat import OpenAIConfig, OpenAICompatibleModel
from praxo.model import Message, Response, ToolCall
from praxo.policy import Decision, FuncHook
from praxo.tool import Registry


class FixtureModel:
    def __init__(self, order):
        self.order = order

    async def generate(self, request):
        if request.messages[-1].role == "tool":
            return Response(message=Message(role="assistant", content=request.messages[-1].content))
        return Response(message=Message(role="assistant", tool_calls=[
            ToolCall(id="review-1", name="review_order", arguments={"order_id": self.order})]))


class ReviewTool:
    name = "review_order"
    description = "Read an order and create a review draft, never a refund."
    risk = "write"
    parameters = {"type": "object", "required": ["order_id"],
                  "properties": {"order_id": {"type": "string"}}}

    def __init__(self, base_url, token, key):
        self.url = urlsplit(base_url)
        if self.url.scheme != "http" or not self.url.hostname or self.url.path not in ("", "/"):
            raise ValueError("Local teaching service requires an HTTP origin")
        self.token, self.key = token, key

    def request(self, method, path, body=None):
        connection = http.client.HTTPConnection(self.url.hostname, self.url.port, timeout=5)
        try:
            connection.request(method, path, json.dumps(body) if body else None,
                               {"Authorization": f"Bearer {self.token}",
                                "Content-Type": "application/json", "Idempotency-Key": self.key})
            response = connection.getresponse()
            data = json.loads(response.read())
            if response.status not in (200, 201):
                raise RuntimeError(f"business service {response.status}: {data['error']}")
            return data
        finally:
            connection.close()

    async def invoke(self, args):
        order = self.request("GET", f"/v1/orders/{args['order_id']}")
        recommendation = "Contact carrier" if order["status"] == "delayed" else "Monitor shipment"
        draft = self.request("POST", f"/v1/orders/{order['id']}/drafts",
                             {"recommendation": recommendation})
        return json.dumps({"order": order, "draft": draft})


async def review(base_url, token, order, allowed_order="order-100", key="python-review-1", model=None):
    tools = Registry()
    tools.register(ReviewTool(base_url, token, key))
    def authorize(action):
        return Decision(allowed=action.kind == "model.generate" or (
            action.kind == "tool.invoke" and action.tool_name == "review_order"
            and action.arguments.get("order_id") == allowed_order), reason="fixed order scope")
    agent = Agent(AgentOptions(model=model or FixtureModel(order), tools=tools, max_steps=3,
                              allowed_tools=["review_order"], policy=FuncHook(authorize)))
    result = await agent.run(Session(id="order-review"), f"Review {order}; create a draft only.")
    return result.output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    parser.add_argument("--order", default="order-100")
    parser.add_argument("--live", action="store_true")
    args = parser.parse_args()
    model = OpenAICompatibleModel(OpenAIConfig(
        base_url=os.getenv("PRAXO_BASE_URL", "http://127.0.0.1:11434/v1"),
        api_key=os.getenv("PRAXO_API_KEY", ""), model=os.getenv("PRAXO_MODEL", "qwen2.5:0.5b"),
    )) if args.live else None
    print(asyncio.run(review(args.base_url, os.getenv("DEMO_TOKEN", "demo-a-token"), args.order, model=model)))
