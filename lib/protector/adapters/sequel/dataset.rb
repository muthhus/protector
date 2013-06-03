module Protector
  module Adapters
    module Sequel
      # Patches `Sequel::Dataset`
      module Dataset
        extend ActiveSupport::Concern

        # Wrapper for the Dataset `row_proc` adding restriction function
        class Restrictor
          attr_accessor :subject
          attr_accessor :mutator

          # Mutate entity through `row_proc` if available and then protect
          #
          # @param entity [Object]          Entity coming from Dataset
          def call(entity)
            entity = mutator.call(entity) if mutator
            return entity if !entity.respond_to?(:restrict!)
            entity.restrict!(@subject)
          end
        end

        included do
          include Protector::DSL::Base

          alias_method_chain :each, :protector
        end

        # Gets {Protector::DSL::Meta::Box} of this dataset
        def protector_meta
          model.protector_meta.evaluate(model, @protector_subject)
        end

        # Sets up an instance of {Restrictor}
        #
        # @param mutator [Proc]               Current value of `@row_proc`
        def protector_restrictor(mutator)
          @protector_restrictor ||= Restrictor.new
          @protector_restrictor.subject = @protector_subject
          @protector_restrictor.mutator = mutator
          @protector_restrictor
        end

        # Substitutes `row_proc` with {Protector} and injects protection scope
        def each_with_protector(*args, &block)
          row_proc = @protector_subject ? protector_restrictor(@row_proc) : @row_proc

          if @opts[:graph]
            graph_each do |r|
              r = restrict!()
              yield r
            end
          else
            if !@protector_subject || !protector_meta.scoped?
              fetch_rows(select_sql){|r| yield row_proc ? row_proc.call(r) : r}
            else
              dataset = clone.instance_eval(&protector_meta.scope_proc)
              dataset.fetch_rows(dataset.select_sql){|r| yield row_proc ? row_proc.call(r) : r}
            end
          end
          self
        end
      end
    end
  end
end