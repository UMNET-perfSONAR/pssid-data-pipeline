require 'json'

def filter(event)
    diags = event.get("[run][limit-diags]") || event.get("[run][diags]")

    # Capture type and raw content, even if nil or unexpected
    event.set("debug_diags_type", diags.class.to_s) if diags
    event.set("debug_raw_diags", diags) if diags

    if diags.is_a?(String)
        json_start = diags.index('{')

        if json_start
            raw_json_str = diags[json_start..-1]
            event.set("debug_extracted_json", raw_json_str)
            
            # Add debug info about JSON string
            event.set("debug_json_length", raw_json_str.length)
            event.set("debug_json_ends_with", raw_json_str[-20..-1]) if raw_json_str.length > 20

            begin
                # Try to parse the JSON as-is first
                parsed = JSON.parse(raw_json_str)
                event.set("[result-full-parsed]", parsed)
                event.set("json_parse_status", "success")
                
            rescue JSON::ParserError => e
                # Check if it looks like truncated JSON
                if raw_json_str.end_with?("'") || !raw_json_str.end_with?('}')
                    event.tag("_json_truncated")
                    event.set("json_parse_error_type", "truncated")
                else
                    event.tag("_json_malformed")
                    event.set("json_parse_error_type", "malformed")
                end
                
                event.tag("_jsonparsefailure")
                event.set("json_parse_error_message", e.message)
                event.set("json_parse_error_position", e.message.scan(/at line (\d+)/).flatten.first) if e.message =~ /at line/
                
            rescue => e
                event.tag("_jsonparsefailure")
                event.set("json_parse_error_message", e.message)
                event.set("json_parse_error_type", "other")
            end
        else
            event.tag("_no_json_found")
        end
    else
        event.tag("_diags_not_string") if diags
    end

    return [event]
end
