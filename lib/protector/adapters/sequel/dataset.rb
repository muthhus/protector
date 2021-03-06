module Protector
  module Adapters
    module Sequel
      # Patches `Sequel::Dataset`
      module Dataset extend ActiveSupport::Concern

        # Wrapper for the Dataset `row_proc` adding restriction function
        class Restrictor
          attr_accessor :subject
          attr_accessor :mutator

          def initialize(subject, mutator)
            @subject = subject
            @mutator = mutator
          end

          # Mutate entity through `row_proc` if available and then protect
          #
          # @param entity [Object]          Entity coming from Dataset
          def call(entity)
            entity = mutator.call(entity) if mutator
            return entity if !entity.respond_to?(:restrict!)
            entity.restrict!(@subject)
          end
        end

        included do |klass|
          include Protector::DSL::Base

          alias_method_chain :each, :protector
        end

        # Gets {Protector::DSL::Meta::Box} of this dataset
        def protector_meta
          model.protector_meta.evaluate(model, @protector_subject)
        end

        # Substitutes `row_proc` with {Protector} and injects protection scope
        def each_with_protector(*args, &block)
          return each_without_protector(*args, &block) if !@protector_subject

          relation = protector_defend_graph(clone, @protector_subject)
          relation = relation.instance_eval(&protector_meta.scope_proc) if protector_meta.scoped?

          relation.row_proc = Restrictor.new(@protector_subject, relation.row_proc)
          relation.each_without_protector(*args, &block)
        end

        # Injects protection scope for every joined graph association
        def protector_defend_graph(relation, subject)
          return relation unless @opts[:eager_graph]

          @opts[:eager_graph][:reflections].each do |association, reflection|
            model = reflection[:cache][:class] if reflection[:cache].is_a?(Hash) && reflection[:cache][:class]
            model = reflection[:class_name].constantize unless model
            meta  = model.protector_meta.evaluate(model, subject)

            relation = relation.instance_eval(&meta.scope_proc) if meta.scoped?
          end

          relation
        end
      end
    end
  end
end