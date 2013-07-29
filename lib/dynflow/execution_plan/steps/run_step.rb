module Dynflow
  module ExecutionPlan::Steps
    class RunStep < Abstract
      def execute
        attributes = persistence_adapter.load_action execution_plan.id, action_id
        action     = action_class.from_hash(attributes, :run_phase, state, self.id, execution_plan.world)

        action.execute
        self.state = action.state

        persistence_adapter.save_action execution_plan.id, action_id, action.to_hash

        return self
      end
    end
  end
end