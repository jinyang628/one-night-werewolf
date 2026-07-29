from enum import StrEnum

from pydantic import BaseModel, Field


class DietPreference(StrEnum):
    spicy = "spicy"
    vegetarian = "vegetarian"
    vegan = "vegan"
    pescatarian = "pescatarian"


class Sex(StrEnum):
    male = "Male"
    female = "Female"
    prefer_not_to_say = "Prefer not to say"


class PreferencesRequest(BaseModel):
    name: str = Field(min_length=1, description="The user's display name.")
    age: int = Field(ge=1, le=120, description="The user's age in years.")
    sex: Sex = Field(description="The user's sex.")
    health_conditions: list[str] = Field(
        default_factory=list,
        description="Health conditions to factor into recommendations.",
    )
    distance_meters: int = Field(
        ge=100,
        le=10000,
        description="The maximum distance in meters for recommendations.",
    )
    budget_level: int = Field(
        ge=1,
        le=4,
        description="The maximum budget level for recommendations, from 1 to 4.",
    )
    diet_preferences: list[DietPreference] = Field(
        default_factory=list,
        description="Dietary preferences to apply to recommendations.",
    )
