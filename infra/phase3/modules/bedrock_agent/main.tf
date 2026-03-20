# Data source for current AWS account
data "aws_caller_identity" "current" {}

# ========================================
# Bedrock Guardrail
# ========================================

resource "aws_bedrock_guardrail" "earthquake_safety" {
  name                      = "${var.project_name}-${var.environment}-earthquake-safety"
  description               = "Guardrail to block earthquake predictions and ensure responsible AI usage"
  blocked_input_messaging   = "I cannot predict future earthquakes. Earthquake prediction is not scientifically possible with current technology. I can analyze historical patterns, assess seismic hazards, and provide real-time monitoring data instead."
  blocked_outputs_messaging = "I cannot provide predictions about future earthquakes. Let me help you understand historical seismic patterns and current monitoring data instead."

  topic_policy_config {
    topics_config {
      name       = "Earthquake Predictions"
      definition = "Requests to predict or forecast FUTURE earthquakes, including when or where they will occur. Does NOT include historical data, recent records, or past seismic activity."
      examples   = [
        "When will the next big earthquake hit Vancouver?",
        "Predict where the next M7.0 will strike",
        "Can you forecast earthquakes for next month?",
        "Will there be an earthquake tomorrow?",
        "Predict future seismic activity"
      ]
      type = "DENY"
    }

    topics_config {
      name       = "Earthquake Conspiracy Theories"
      definition = "Conspiracy theories about earthquake causes, such as government weather control, secret weapons, or unscientific claims about earthquake generation."
      examples   = [
        "Are earthquakes caused by HAARP?",
        "Is the government creating earthquakes?",
        "Tell me about earthquake weapons"
      ]
      type = "DENY"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-earthquake-safety"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ========================================
# IAM Role for Bedrock Agent
# ========================================

resource "aws_iam_role" "agent" {
  name = "${var.project_name}-${var.environment}-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-agent-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Policy for Bedrock Agent
resource "aws_iam_role_policy" "agent" {
  name = "${var.project_name}-${var.environment}-agent-policy"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeFoundationModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:*:*:inference-profile/*"
        ]
      },
      {
        Sid    = "InvokeToolLambdas"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.get_recent_earthquakes_lambda_arn,
          var.analyze_historical_patterns_lambda_arn,
          var.get_hazard_assessment_lambda_arn,
          var.get_location_context_lambda_arn,
          var.fetch_weather_at_epicenter_lambda_arn
        ]
      },
      {
        Sid    = "RetrieveFromKnowledgeBase"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/${var.knowledge_base_id}"
      },
      {
        Sid    = "ApplyGuardrail"
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Resource = aws_bedrock_guardrail.earthquake_safety.guardrail_arn
      }
    ]
  })
}

# ========================================
# Lambda Resource-Based Policy (Allow Bedrock to invoke)
# ========================================

resource "aws_lambda_permission" "allow_bedrock_get_recent_earthquakes" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.get_recent_earthquakes_lambda_arn
  principal     = "bedrock.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn    = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"
}

resource "aws_lambda_permission" "allow_bedrock_analyze_historical_patterns" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.analyze_historical_patterns_lambda_arn
  principal     = "bedrock.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn    = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"
}

resource "aws_lambda_permission" "allow_bedrock_get_hazard_assessment" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.get_hazard_assessment_lambda_arn
  principal     = "bedrock.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn    = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"
}

resource "aws_lambda_permission" "allow_bedrock_get_location_context" {
  statement_id   = "AllowBedrockInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = var.get_location_context_lambda_arn
  principal      = "bedrock.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"
}

resource "aws_lambda_permission" "allow_bedrock_fetch_weather_at_epicenter" {
  statement_id   = "AllowBedrockInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = var.fetch_weather_at_epicenter_lambda_arn
  principal      = "bedrock.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"
}

# ========================================
# Bedrock Agent
# ========================================

resource "aws_bedrockagent_agent" "main" {
  agent_name              = "${var.project_name}-${var.environment}-agent"
  agent_resource_role_arn = aws_iam_role.agent.arn
  foundation_model        = "us.anthropic.claude-sonnet-4-20250514-v1:0"
  description             = "AI assistant for earthquake monitoring and seismic data analysis"
  idle_session_ttl_in_seconds = 1800

  instruction = <<-EOT
You are an expert seismologist assistant for GroundSense, a Canadian earthquake monitoring system.

Your capabilities:
- Query recent earthquake data from the last 30 days
- Analyze historical seismic patterns using multi-year datasets
- Retrieve narrative context from official reports and bulletins

Guidelines:
1. ALWAYS cite sources when referencing documents (include PDF names)
2. NEVER make earthquake predictions - earthquakes are unpredictable
3. Use precise scientific terminology but explain jargon for general audiences
4. When showing statistics, provide context (e.g., "This is X% above historical average")
5. If uncertain, check multiple data sources before answering
6. On follow-up questions that compare to prior results (e.g. "vs last year"), use the same geographic region and magnitude threshold as the previous turn unless the user changes them

Response format:
- Start with direct answer
- Show relevant data (numbers, trends)
- Provide context from reports when available
- Suggest follow-up questions if appropriate
EOT

  # Guardrail temporarily disabled for testing tool-calling
  # guardrail_configuration {
  #   guardrail_identifier = aws_bedrock_guardrail.earthquake_safety.guardrail_arn
  #   guardrail_version    = aws_bedrock_guardrail.earthquake_safety.version
  # }

  tags = {
    Name        = "${var.project_name}-${var.environment}-agent"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ========================================
# Action Group 1: Recent Data Queries
# ========================================

resource "aws_bedrockagent_agent_action_group" "recent_data" {
  agent_id      = aws_bedrockagent_agent.main.agent_id
  agent_version = "DRAFT"
  action_group_name = "RecentDataQueries"
  description       = "Query recent earthquake events from the last 30 days"
  
  action_group_executor {
    lambda = var.get_recent_earthquakes_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "get_recent_earthquakes"
        description = "Retrieve recent earthquake events from DynamoDB (last 30 days). Use this when users ask about current seismic activity, recent earthquakes, or what happened recently."
        
        parameters {
          map_block_key = "min_magnitude"
          type          = "number"
          description   = "Minimum earthquake magnitude threshold (e.g., 0.0, 4.0, 5.0)"
          required      = false
        }

        parameters {
          map_block_key = "max_magnitude"
          type          = "number"
          description   = "Maximum earthquake magnitude threshold (default: 10.0)"
          required      = false
        }

        parameters {
          map_block_key = "region"
          type          = "string"
          description   = "Geographic region filter. Valid values: 'canada', 'atlantic', 'pacific' (pacific includes northern coastal AK–BC / Yakutat corridor). Leave empty for all regions."
          required      = false
        }

        parameters {
          map_block_key = "limit"
          type          = "integer"
          description   = "Maximum number of earthquake events to return (default: 50)"
          required      = false
        }
      }
    }
  }
}

# ========================================
# Action Group 2: Historical Analytics
# ========================================

resource "aws_bedrockagent_agent_action_group" "historical_analytics" {
  agent_id      = aws_bedrockagent_agent.main.agent_id
  agent_version = "DRAFT"
  action_group_name = "HistoricalAnalytics"
  description       = "Analyze long-term seismic trends and patterns using Athena"
  
  action_group_executor {
    lambda = var.analyze_historical_patterns_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "analyze_historical_patterns"
        description = "Run Athena queries on historical earthquake data for trend analysis. Use this when users ask about historical patterns, long-term trends, averages, or multi-year comparisons."
        
        parameters {
          map_block_key = "query_type"
          type          = "string"
          description   = "Type of analysis to perform. Valid values: 'count' (total earthquakes), 'average' (statistics), 'max' (strongest events), 'timeseries' (monthly trends)"
          required      = true
        }

        parameters {
          map_block_key = "time_range_days"
          type          = "integer"
          description   = "Number of days to analyze (default: 365 for 1 year)"
          required      = false
        }

        parameters {
          map_block_key = "min_magnitude"
          type          = "number"
          description   = "Minimum earthquake magnitude threshold (default: 0.0)"
          required      = false
        }

        parameters {
          map_block_key = "region"
          type          = "string"
          description   = "Geographic region filter. Valid values: 'canada', 'atlantic', 'pacific' (pacific includes northern coastal AK–BC / Yakutat corridor). Leave empty for all regions."
          required      = false
        }
      }
    }
  }
}

# ========================================
# Action Group 3: Knowledge Base Retrieval
# ========================================

resource "aws_bedrockagent_agent_action_group" "knowledge_base" {
  agent_id      = aws_bedrockagent_agent.main.agent_id
  agent_version = "DRAFT"
  action_group_name = "KnowledgeBaseRetrieval"
  description       = "Retrieve context from seismic hazard reports and bulletins"
  
  action_group_executor {
    lambda = var.get_hazard_assessment_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "get_hazard_assessment"
        description = "Search the knowledge base for information from earthquake reports, hazard assessments, and research documents. Use this when users ask about seismic hazard, risk assessments, historical narratives, or specific locations mentioned in reports."
        
        parameters {
          map_block_key = "query"
          type          = "string"
          description   = "Natural language search query or question about earthquake reports and hazard assessments"
          required      = true
        }

        parameters {
          map_block_key = "max_results"
          type          = "integer"
          description   = "Maximum number of relevant document chunks to return (default: 5)"
          required      = false
        }
      }
    }
  }
}

# ========================================
# Action Group 4: Location Intelligence
# ========================================

resource "aws_bedrockagent_agent_action_group" "location_intelligence" {
  agent_id          = aws_bedrockagent_agent.main.agent_id
  agent_version     = "DRAFT"
  action_group_name = "LocationIntelligence"
  description       = "Geocode place names and retrieve tectonic/seismic context from the Knowledge Base"

  action_group_executor {
    lambda = var.get_location_context_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "get_location_context"
        description = "Provides geographic and geological context about earthquake locations. Geocodes place names or reverse-geocodes coordinates, then queries the Knowledge Base for tectonic setting, fault systems, and seismic hazard information for that region. Use when users ask about the tectonic setting, fault systems, or seismic hazard of a specific location."

        parameters {
          map_block_key = "location_name"
          type          = "string"
          description   = "Place name to look up (e.g., 'Vancouver', 'Cascadia Subduction Zone', 'Halifax'). Provide this OR latitude/longitude."
          required      = false
        }

        parameters {
          map_block_key = "latitude"
          type          = "number"
          description   = "Latitude of the location in decimal degrees. Provide with longitude as an alternative to location_name."
          required      = false
        }

        parameters {
          map_block_key = "longitude"
          type          = "number"
          description   = "Longitude of the location in decimal degrees. Provide with latitude as an alternative to location_name."
          required      = false
        }

        parameters {
          map_block_key = "max_kb_results"
          type          = "integer"
          description   = "Maximum number of Knowledge Base document chunks to return (default: 5)"
          required      = false
        }
      }
    }
  }
}

# ========================================
# Action Group 5: Weather Context
# ========================================

resource "aws_bedrockagent_agent_action_group" "weather_context" {
  agent_id          = aws_bedrockagent_agent.main.agent_id
  agent_version     = "DRAFT"
  action_group_name = "WeatherContext"
  description       = "Retrieve current or historical weather conditions at earthquake epicenters"

  action_group_executor {
    lambda = var.fetch_weather_at_epicenter_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "fetch_weather_at_epicenter"
        description = "Retrieves weather conditions (temperature, wind, precipitation) at an earthquake epicenter using the Open-Meteo API. Includes a seismic noise risk assessment explaining how weather may affect aftershock detection. Use when users ask about weather conditions during an earthquake, or whether weather could affect seismometer readings or emergency response."

        parameters {
          map_block_key = "latitude"
          type          = "number"
          description   = "Epicenter latitude in decimal degrees (required)"
          required      = true
        }

        parameters {
          map_block_key = "longitude"
          type          = "number"
          description   = "Epicenter longitude in decimal degrees (required)"
          required      = true
        }

        parameters {
          map_block_key = "event_time"
          type          = "string"
          description   = "ISO 8601 datetime of the earthquake for historical weather lookup (e.g., '2024-03-15T14:30:00'). Omit for current conditions."
          required      = false
        }
      }
    }
  }
}

# ========================================
# Agent Alias (for invoking the agent)
# ========================================

resource "aws_bedrockagent_agent_alias" "main" {
  agent_id         = aws_bedrockagent_agent.main.agent_id
  agent_alias_name = "v1"
  description      = "Primary alias - no guardrail for testing"

  tags = {
    Name        = "${var.project_name}-${var.environment}-agent-v1"
    Project     = var.project_name
    Environment = var.environment
  }
}
