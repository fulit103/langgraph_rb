require 'json'
require 'yaml'
require 'fileutils'

module LangGraphRB
  module Stores
    # Abstract base class for memory stores
    class BaseStore
      def save(thread_id, state, step_number, metadata = {})
        raise NotImplementedError, "Subclasses must implement #save"
      end

      def load(thread_id, step_number = nil)
        raise NotImplementedError, "Subclasses must implement #load"
      end

      def list_threads
        raise NotImplementedError, "Subclasses must implement #list_threads"
      end

      def delete(thread_id)
        raise NotImplementedError, "Subclasses must implement #delete"
      end

      def list_steps(thread_id)
        raise NotImplementedError, "Subclasses must implement #list_steps"
      end
    end

    # In-memory store (not persistent across process restarts)
    class InMemoryStore < BaseStore
      def initialize
        @data = {}
      end

      def save(thread_id, state, step_number, metadata = {})
        @data[thread_id] ||= {}
        @data[thread_id][step_number] = {
          state: deep_copy(state),
          timestamp: Time.now,
          metadata: metadata
        }
      end

      def load(thread_id, step_number = nil)
        thread_data = @data[thread_id]
        return nil unless thread_data

        if step_number
          checkpoint = thread_data[step_number]
          return nil unless checkpoint
          
          {
            state: deep_copy(checkpoint[:state]),
            step_number: step_number,
            timestamp: checkpoint[:timestamp],
            metadata: checkpoint[:metadata]
          }
        else
          # Return latest checkpoint
          latest_step = thread_data.keys.max
          return nil unless latest_step
          
          checkpoint = thread_data[latest_step]
          {
            state: deep_copy(checkpoint[:state]),
            step_number: latest_step,
            timestamp: checkpoint[:timestamp],
            metadata: checkpoint[:metadata]
          }
        end
      end

      def list_threads
        @data.keys
      end

      def delete(thread_id)
        @data.delete(thread_id)
      end

      def list_steps(thread_id)
        thread_data = @data[thread_id]
        return [] unless thread_data

        thread_data.keys.sort
      end

      def clear
        @data.clear
      end

      private

      def deep_copy(obj)
        case obj
        when Hash
          obj.transform_values { |v| deep_copy(v) }
        when Array
          obj.map { |v| deep_copy(v) }
        else
          obj.dup rescue obj
        end
      end
    end

    # File-based store using YAML
    class FileStore < BaseStore
      def initialize(base_path)
        @base_path = base_path
        FileUtils.mkdir_p(@base_path) unless Dir.exist?(@base_path)
      end

      def save(thread_id, state, step_number, metadata = {})
        thread_dir = File.join(@base_path, thread_id.to_s)
        FileUtils.mkdir_p(thread_dir) unless Dir.exist?(thread_dir)

        checkpoint_file = File.join(thread_dir, "#{step_number}.yml")
        
        data = {
          state: state.to_h,
          timestamp: Time.now,
          metadata: metadata
        }

        File.write(checkpoint_file, YAML.dump(data))
      end

      def load(thread_id, step_number = nil)
        thread_dir = File.join(@base_path, thread_id.to_s)
        return nil unless Dir.exist?(thread_dir)

        if step_number
          checkpoint_file = File.join(thread_dir, "#{step_number}.yml")
          return nil unless File.exist?(checkpoint_file)

          data = YAML.load_file(checkpoint_file)
          {
            state: State.new(data['state']),
            step_number: step_number,
            timestamp: data['timestamp'],
            metadata: data['metadata'] || {}
          }
        else
          # Find latest checkpoint
          files = Dir.glob(File.join(thread_dir, "*.yml"))
          return nil if files.empty?

          latest_file = files.max_by do |file|
            File.basename(file, '.yml').to_i
          end

          step_num = File.basename(latest_file, '.yml').to_i
          data = YAML.load_file(latest_file)
          
          {
            state: State.new(data['state']),
            step_number: step_num,
            timestamp: data['timestamp'],
            metadata: data['metadata'] || {}
          }
        end
      end

      def list_threads
        Dir.entries(@base_path).select do |entry|
          File.directory?(File.join(@base_path, entry)) && entry != '.' && entry != '..'
        end
      end

      def delete(thread_id)
        thread_dir = File.join(@base_path, thread_id.to_s)
        FileUtils.rm_rf(thread_dir) if Dir.exist?(thread_dir)
      end

      def list_steps(thread_id)
        thread_dir = File.join(@base_path, thread_id.to_s)
        return [] unless Dir.exist?(thread_dir)

        Dir.glob(File.join(thread_dir, "*.yml")).map do |file|
          File.basename(file, '.yml').to_i
        end.sort
      end
    end

    # JSON-based store
    class JsonStore < BaseStore
      def initialize(base_path)
        @base_path = base_path
        FileUtils.mkdir_p(@base_path) unless Dir.exist?(@base_path)
      end

      def save(thread_id, state, step_number, metadata = {})
        thread_dir = File.join(@base_path, thread_id.to_s)
        FileUtils.mkdir_p(thread_dir) unless Dir.exist?(thread_dir)

        checkpoint_file = File.join(thread_dir, "#{step_number}.json")
        
        data = {
          state: state.to_h,
          timestamp: Time.now.iso8601,
          metadata: metadata
        }

        File.write(checkpoint_file, JSON.pretty_generate(data))
      end

      def load(thread_id, step_number = nil)
        thread_dir = File.join(@base_path, thread_id.to_s)
        return nil unless Dir.exist?(thread_dir)

        if step_number
          checkpoint_file = File.join(thread_dir, "#{step_number}.json")
          return nil unless File.exist?(checkpoint_file)

          data = JSON.parse(File.read(checkpoint_file))
          {
            state: State.new(data['state']),
            step_number: step_number,
            timestamp: Time.parse(data['timestamp']),
            metadata: data['metadata'] || {}
          }
        else
          # Find latest checkpoint
          files = Dir.glob(File.join(thread_dir, "*.json"))
          return nil if files.empty?

          latest_file = files.max_by do |file|
            File.basename(file, '.json').to_i
          end

          step_num = File.basename(latest_file, '.json').to_i
          data = JSON.parse(File.read(latest_file))
          
          {
            state: State.new(data['state']),
            step_number: step_num,
            timestamp: Time.parse(data['timestamp']),
            metadata: data['metadata'] || {}
          }
        end
      end

      def list_threads
        Dir.entries(@base_path).select do |entry|
          File.directory?(File.join(@base_path, entry)) && entry != '.' && entry != '..'
        end
      end

      def delete(thread_id)
        thread_dir = File.join(@base_path, thread_id.to_s)
        FileUtils.rm_rf(thread_dir) if Dir.exist?(thread_dir)
      end

      def list_steps(thread_id)
        thread_dir = File.join(@base_path, thread_id.to_s)
        return [] unless Dir.exist?(thread_dir)

        Dir.glob(File.join(thread_dir, "*.json")).map do |file|
          File.basename(file, '.json').to_i
        end.sort
      end
    end
  end
end 