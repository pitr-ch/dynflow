module Dynflow
  module Action::PlanPhase
    attr_reader :execution_plan, :trigger

    def self.included(base)
      base.attr_indifferent_access_hash :input
    end

    def initialize(attributes, execution_plan, trigger)
      super attributes, execution_plan.world
      plan_step_id || raise(ArgumentError, 'missing plan_step_id')

      self.input      = attributes[:input] || {}
      @execution_plan = is_kind_of! execution_plan, ExecutionPlan
      @plan_step_id   = plan_step_id
      @trigger        = is_kind_of! trigger, Action, NilClass
    end

    def execute(*args)
      with_error_handling do
        execution_plan.switch_flow(Flows::Concurrence.new([])) do
          plan(*args)
        end

        subscribed_actions = world.subscribed_actions(self.action_class)
        if subscribed_actions.any?
          # we ancapsulate the flow for this action into a concurrence and
          # add the subscribed flows to it as well.
          trigger_flow = execution_plan.current_run_flow.sub_flows.pop
          execution_plan.switch_flow(Flows::Concurrence.new([trigger_flow])) do
            subscribed_actions.each do |action_class|
              execution_plan.add_plan_step(action_class, self).execute(self, *args)
            end
          end
        end
      end
    end

    def to_hash
      super.merge input: input
    end

    # DSL for plan method

    def concurrence(&block)
      execution_plan.switch_flow(Flows::Concurrence.new([]), &block)
    end

    def sequence(&block)
      execution_plan.switch_flow(Flows::Sequence.new([]), &block)
    end

    def plan_self(input)
      @input = input
      if self.respond_to?(:run)
        run_step          = execution_plan.add_run_step(self)
        @output_reference = ExecutionPlan::OutputReference.new(run_step.id)
      end

      execution_plan.add_finalize_step(self) if self.respond_to?(:finalize)
      return self # to stay consistent with plan_action
    end

    def plan_action(action_class, *args)
      execution_plan.add_plan_step(action_class, self).execute(nil, *args)
    end

    def output
      unless @output_reference
        raise 'plan_self has to be invoked before being able to reference the output'
      end

      return @output_reference
    end

  end
end