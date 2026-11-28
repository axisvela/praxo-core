from .behavior_scenario_builders import Scenario
from .behavior_scenarios_authorization import scenarios_authorization
from .behavior_scenarios_state import scenarios_state
from .behavior_scenarios_streaming import scenarios_streaming


def scenarios() -> tuple[Scenario, ...]:
    return scenarios_authorization() + scenarios_state() + scenarios_streaming()
