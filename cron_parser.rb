require 'date'
require './field_value_exception'

class CronParser
    attr_accessor :command
    attr_accessor :minute, :hour, :day_of_month, :month, :day_of_week
    attr_accessor :errors
    attr_accessor :fields

    # Extract string representations of the day and month values into arrays.
    DAYS = Date::ABBR_DAYNAMES.map(&:upcase)
    MONTHS = Date::ABBR_MONTHNAMES.compact.map(&:upcase)

    # Each field has a valid range of values. Store these to allow us to sense check
    # and validatate the inputs.
    RANGES = {
        minute: (0..59).to_a,
        hour: (0..23).to_a,
        day_of_month: (1..31).to_a,
        month: (1..12).to_a,
        day_of_week: (0..6).to_a
    }

    def initialize(cron_string)
        self.errors = {}
        fields = process_cron(cron_string)

        fields.each do |field, value| 
            parse(field, value)
        end
    end

    # Returns true if there were no errors while parsing the cron string.
    def valid?
        self.errors.empty?
    end

    def next_run
        date = Time.now

        next_day_of_month = day_of_month.split(' ').find { |d| d.to_i >= date.day }
        next_month = month.split(' ').find { |m| m.to_i >= date.month  }


        # Date.new(...)
    end

    private

    # Processes the cron string and returns the parsed set of fields.
    # Also sets the self.fields and self.command properties.
    #
    # Input: 
    #   cron_string: String or array of cron values.
    #
    # Example:
    #   process_input("*/15 0 1,15 * 1-5 /usr/bin/find")
    #       => {minute: '*/15', hour: '0', day_of_month: '1,15', month: '*', day_of_week: '1-5'}
    def process_cron(cron_string)
        # Sanitise the input if needed.
        cron_string = cron_string.join(' ') if cron_string.is_a?(Array)

        # Take the first 5 fields as the time values.
        values = cron_string.split[0..4]
        minute, hour, day_of_month, month, day_of_week = values

        # Return the rest of the string as the command section. 
        self.command = cron_string.split[5..].join(' ')

        self.fields = {
            minute: minute,
            hour: hour,
            day_of_month: day_of_month,
            month: month,
            day_of_week: day_of_week
        }
    end

    # Parse and expand the cron field value into the complete list of times.
    # Uses the characters within the value to determine the type of field to parse.
    #
    # Input:
    #   field: The field name to process.
    #   value: The value for that field.
    #
    # Example:
    #   parse(:minute, '*/15')
    #       => "0 15 30 45"
    #   parse(:day_of_week, 'MON-FRI')
    #       => "MON TUE WED THU FRI"
    def parse(field, value)
        case value 
        when '*'    then set_field(field, RANGES[field].join(' '))
        when '?'    then set_field(field, 'Unused')
        when /\w{3}-\w{3},\w{3}/ then set_field(field, parse_range(field, value.split(',')[0]) + ' ' + parse_literal(field, value.split(',')[1]))
        when /-/    then set_field(field, parse_range(field, value))
        when /\//   then set_field(field, parse_interval(field, value))
        when /,/    then set_field(field, parse_list(field, value))
        else             set_field(field, parse_literal(field, value)) 
        end
    end

    # Dynamically access the field setter to store the value on the property.
    def set_field(field, value)
        self.send("#{field}=", value)
    end

    # Takes a literal value and verifies that it is allowed with in the range.
    #
    # Input:
    #   field: The field name to process.
    #   value: The value for that field.
    #
    # Example:
    #   parse_literal(:minute, '20')
    #       => '20'
    def parse_literal(field, value)
        # Validate that the value is within the allowed range for the field.
        if !within_field_range?(field, value)
            field_name = field.to_s.gsub('_', ' ').capitalize
            raise FieldValueException.new "#{field_name} value #{value} is invalid."
        end

        value

    rescue FieldValueException => e
        add_error(field, e.message)
        nil
    end

    # Takes a range of values and verifies that each value is allowed within the field range.
    # Returns every value between the range specified.
    #
    # Input:
    #   field: The field name to process.
    #   value: The value for that field.
    #
    # Example:
    #   parse_range(:minute, '5-10')
    #       => '5 6 7 8 9 10'
    def parse_range(field, value)
        lower, upper = value.split('-')

        if !within_field_range?(field, lower) || !within_field_range?(field, upper)
            field_name = field.to_s.gsub('_', ' ').capitalize
            raise FieldValueException.new "#{field_name} range #{value} is invalid."
        end

        if (lower =~ /\d+/)
            # Convert to integers for range lookup
            lower, upper = lower.to_i, upper.to_i
            RANGES[field][(lower..upper)].join(' ')
        else
            # If the field is month then use the month strings otherwise it
            # will be days of the week so use the day strings.
            string_values = field == :month ? MONTHS : DAYS
            
            # Convert string values to indicies and extract the values from the string representations.
            lower, upper = string_values.find_index(lower.upcase), string_values.find_index(upper.upcase)

            if (upper < lower)
                upper_values = string_values[(lower..)]
                lower_values = string_values[(..upper)]

                (upper_values + lower_values).join(' ')
            else
                string_values[(lower..upper)].join(' ')
            end
        end

    rescue FieldValueException => e
        add_error(field, e.message)
        nil
    end

    # Takes an interval and verifies that the starting point is within the allowed range and returns
    # all the values from the range that match the interval scale.
    # 
    # Input:
    #   field: The field name to process.
    #   value: The value for that field.
    #
    # Example: 
    #   parse_interval(:minute, '*/15')
    #       => '0 15 30 45'
    #   parse_interval(:month, '2/3')
    #       => '2 5 8 11'
    def parse_interval(field, value)
        first, second = value.split('/')

        if first == '*'
            # The interval check will be performed on all possible values of the field.
            RANGES[field].select.with_index { |_, i| i % second.to_i == 0 }.join(' ') 
        else
            # Ensure that the provided value is within the valid range.
            if !within_field_range?(field, first) or !within_field_range?(field, second)
                field_name = field.to_s.gsub('_', ' ').capitalize
                raise FieldValueException.new "#{field_name} interval #{value} is not valid."
            end

            # We check for a valid interval by comparing the interval value against the index of the field. 
            # This allows us to perform a modulo (remainder) check to see if the field is valid.
            if first =~ /\d+/
                # Find the first field which matches a literal and check for matching indicies from that point.
                start_index = RANGES[field].find_index(first.to_i)
                RANGES[field][(start_index..)].select.with_index { |_, i| i % second.to_i == 0}.join(' ')
            else
                # Perform a lookup on months or days to get the correct value index for the field before checking
                # to see if the indicies match the interval from that point.
                string_values = field == :month ? MONTHS : DAYS
                start_index = string_values.find_index(first)

                # This will return the values within the range as strings. Could change to perform the lookup on the
                # interger values here if needed.
                string_values[(start_index..)].select.with_index { |_, i| i % second.to_i == 0}.join(' ')
            end
        end

    rescue FieldValueException => e
        add_error(field, e.message)
        nil
    end

    # Takes a list of values and validates that each value is allowed within the range.
    # Returns the valid list.
    #
    # Input:
    #   field: The field name to process.
    #   value: The value for that field.
    #
    # Example:
    #   parse_list(:hour, '1,5,7,9')
    #       => '1 5 7 9'
    def parse_list(field, value)
        list = value.split(',')

        # If any of the values in the list are invalid raise an error.
        if list.any? { |v| !within_field_range?(field, v) }
            field_name = field.to_s.gsub('_', ' ').capitalize
            raise FieldValueException.new "#{field_name} list #{value} is not valid."
        end

        # Simply return the value again as we know it already contains every case we need.
        # Could do a look up to convert string values to integer values here if needed.
        value.upcase.gsub(',', ' ')

    rescue FieldValueException => e
        add_error(field, e.message)
        nil
    end

    # Check both ranges and string values to ensure that the provided field value
    # is within the allowed range.
    #
    # Inputs:
    #   field: The field name to process.
    #   value: The value for that field.
    #
    # Example:
    #   within_field_range?(:day, 80)
    #       => false
    #   within_field_range?(:month, 'FEB')
    #       => true
    def within_field_range?(field, value)
        if value.is_a?(Integer) || value =~ /\d+/
            RANGES[field].include?(value.to_i)
        else
            string_values = field == :month ? MONTHS : DAYS
            string_values.include?(value.upcase)
        end
    end

    # Adds a message to the error hash for the specified field.
    def add_error(field, message)
        self.errors[field] = message
    end
end
