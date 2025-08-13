module Langgraph
  module Middleware
    class JobContextPropagation
      def call(_worker, msg, _queue)
        Thread.current[:langgraph_run_id] = msg['run_id']
        yield
      ensure
        Thread.current[:langgraph_run_id] = nil
      end
    end
  end
end
