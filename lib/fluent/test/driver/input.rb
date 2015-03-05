#
# Fluentd
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

require 'fluent/test/driver/base'

module Fluent
  # TODO: Chekc What is this for?
  class FileBuffer < BasicBuffer
    def self.clear_buffer_paths
      @@buffer_paths = {}
    end
  end

  module Test
    module Driver
      class Input < Base
        attr_accessor :run_timeout
        attr_reader :emit_streams

        def initialize(klass, &block)
          FileBuffer.clear_buffer_paths

          super(klass, &block)

          @emit_streams = []
        end

        def emits
          all = []
          @emit_streams.each {|tag,events|
            events.each {|time,record|
              all << [tag, time, record]
            }
          }
          all
        end

        def events
          emits.map{|tag, time record| [time, record] }
        end

        def records
          emits.map{|tag, time, record| record }
        end

        def run(&block)
          m = method(:emit_stream)
          Engine.define_singleton_method(:emit_stream) {|tag,es|
            m.call(tag, es)
          }
          instance.router.define_singleton_method(:emit_stream) {|tag,es|
            m.call(tag, es)
          }
          super {
            block.call if block

            if @expected_emits_length || @run_post_conditions
              # counters for emits and emit_streams
              emitted_count = 0
              emit_times_count = 0

              # Events of expected length will be emitted at the end.
              if @expected_emits_length
                register_run_post_condition do
                  emitted_count >= max_length
                end
              end

              # Set runnning timeout to avoid infinite loop caused by some errors.
              started_at = Time.now
              register_run_breaking_condition do
                Time.now >= started_at + @run_timeout
              end

              until stop?
                if emit_times_count == @emit_streams.length
                  sleep 0.01
                  next
                end

                tag, events = @emit_streams[j]
                emitted_count += events.length
              end
            end
          }
          self
        end

        private
        def emit_stream(tag, es)
          @emit_streams << [tag, es.to_a]
        end
      end
    end
  end
end
