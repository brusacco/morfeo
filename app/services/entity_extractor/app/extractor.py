import os
from threading import Lock

from gliner2 import AutoExtractor


MODEL_NAME = os.getenv("GLINER_MODEL", "fastino/gliner2.5-multi-v1")

ENTITY_TYPES = {
    "person": "Names of specific people",
    "company": "Companies and private businesses",
    "government_institution": "Government ministries, agencies and public institutions",
    "political_party": "Political parties and political movements",
    "organization": "Organizations and associations",
    "country": "Countries",
    "location": "Cities, departments, regions and geographic places",
}

# Keep inference serialized initially. This protects the production server while
# we benchmark CPU/RAM usage. It can be relaxed later if measurements support it.
_inference_lock = Lock()


class EntityExtractor:
    def __init__(self):
        self.model = AutoExtractor.from_pretrained(MODEL_NAME)

    def extract(self, text: str) -> list[dict]:
        with _inference_lock:
            result = self.model.extract_entities(
                text,
                ENTITY_TYPES,
                include_confidence=True,
                include_spans=True,
            )

        entities = []
        for entity_type, matches in result.get("entities", {}).items():
            for match in matches:
                entities.append(
                    {
                        "text": match["text"],
                        "type": entity_type,
                        "confidence": float(match.get("confidence", 0.0)),
                        "start": int(match["start"]),
                        "end": int(match["end"]),
                    }
                )

        return entities
