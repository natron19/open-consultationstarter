FactoryBot.define do
  factory :consultation_plan do
    consultation
    purpose_statement       { "Decide whether to do X, with a clear trigger for revisiting." }
    success_criteria        { ["Criterion 1", "Criterion 2", "Criterion 3"].to_json }
    pre_meeting_questions   { [{ "question" => "Q1?", "principle" => "Search for Truth" }].to_json }
    facilitator_prompts     { [{ "order" => 1, "principle" => "Spirit of Service", "prompt" => "Open prompt.", "when_to_use" => "At the start." }].to_json }
    decision_record_template { "## Decision\n[placeholder]" }
    gemini_raw              { '{"purpose_statement":"Test","success_criteria":["c1","c2","c3"],"pre_meeting_questions":[{"question":"Q?","principle":"Search for Truth"}],"facilitator_prompts":[{"order":1,"principle":"Spirit of Service","prompt":"P","when_to_use":"W"}],"decision_record_template":"## Decision\n[placeholder]"}' }
  end
end
