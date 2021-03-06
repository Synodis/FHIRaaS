Class FHIRAAS.API.spec Extends %REST.Spec [ ProcedureBlock ]
{

XData OpenAPI [ MimeType = application/json ]
{
{
  "swagger": "2.0",
  "info": {
    "title": "Iris Management",
    "description": "Iris Api to manage tenants",
    "version": "1.0.0"
  },
  "host": "api.fhir.fr",
  "basePath": "/v1/management/",
  "schemes": [
    "http"
  ],
  "paths": {
    "/tenants/_spec": {
      "get": {
        "summary": "Get this spec",
        "operationId": "getSpec",
        "responses": {
          "200": {
            "description": "OK"
          },
          "404": {
            "description": "Not Found"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    },
    "/tenants": {
      "get": {
        "summary": "Returns a list of tenants.",
        "operationId": "getTenants",
        "description": "Return the list of available tenant on this Iris instance.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/tenant"
              }
            }
          }
        }
      }
    },
    "/tenants/{tenantId}": {
      "get": {
        "summary": "Returns a tenant by ID.",
        "operationId": "getTenant",
        "parameters": [
          {
            "in": "path",
            "name": "tenantId",
            "required": true,
            "type": "string",
            "description": "the tenant Id"
          }
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {
              "$ref": "#/definitions/tenant"
            }
          },
          "404": {
            "description": "Not Found"
          }
        }
      },
      "put": {
        "summary": "Create a tenant with an ID.",
        "operationId": "putTenant",
        "parameters": [
          {
            "in": "path",
            "name": "tenantId",
            "required": true,
            "type": "string",
            "description": "the tenant Id"
          },
          {
            "in": "body",
            "name": "tenantInformations",
            "schema": {
              "$ref": "#/definitions/createTenant"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {
              "$ref": "#/definitions/pendingEndpoint"
            }
          },
          "404": {
            "description": "Not Found"
          },
          "500": {
            "description": "Server error"
          }
        }
      },
      "delete": {
        "summary": "Delete a tenant with an ID.",
        "operationId": "deleteTenant",
        "parameters": [
          {
            "in": "path",
            "name": "tenantId",
            "required": true,
            "type": "string",
            "description": "the tenant Id"
          }
        ],
        "responses": {
          "200": {
            "description": "OK"
          },
          "404": {
            "description": "Not Found"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    },
    "/tenants/{tenantId}/{endpointId}": {
      "get": {
        "summary": "Returns a tenant by ID.",
        "operationId": "getEndpoint",
        "parameters": [
          {
            "in": "path",
            "name": "tenantId",
            "required": true,
            "type": "string",
            "description": "the tenant Id"
          },
          {
            "in": "path",
            "name": "endpointId",
            "required": true,
            "type": "string",
            "description": "the endpoint Id"
          }
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {
              "$ref": "#/definitions/endpoint"
            }
          },
          "404": {
            "description": "Not Found"
          }
        }
      },
      "put": {
        "summary": "Create a endpoint with an ID.",
        "operationId": "putEndpoint",
        "parameters": [
          {
            "in": "path",
            "name": "tenantId",
            "required": true,
            "type": "string",
            "description": "the tenant Id"
          },
          {
            "in": "path",
            "name": "endpointId",
            "required": true,
            "type": "string",
            "description": "the endpoint Id"
          },
          {
            "in": "body",
            "name": "tenantInformations",
            "schema": {
              "$ref": "#/definitions/createTenant"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {
              "$ref": "#/definitions/pendingEndpoint"
            }
          },
          "404": {
            "description": "Not Found"
          },
          "500": {
            "description": "Server error"
          }
        }
      },
      "delete": {
        "summary": "Delete a endpoint with an ID.",
        "operationId": "deleteEndpoint",
        "parameters": [
          {
            "in": "path",
            "name": "tenantId",
            "required": true,
            "type": "string",
            "description": "the tenant Id"
          },
          {
            "in": "path",
            "name": "endpointId",
            "required": true,
            "type": "string",
            "description": "the endpoint Id"
          }
        ],
        "responses": {
          "200": {
            "description": "OK"
          },
          "404": {
            "description": "Not Found"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    }
  },
  "definitions": {
    "pendingEndpoint": {
      "type": "object",
      "properties": {
        "job_key": {
          "type": "string"
        },
        "status": {
          "type": "string"
        },
        "type": {
          "type": "string"
        },
        "name": {
          "type": "string"
        }
      }
    },
    "endpoint": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "enabled": {
          "type": "boolean"
        },
        "service_config_data": {
          "$ref": "#/definitions/service_config_data"
        },
        "csp_config": {
          "$ref": "#/definitions/csp_config"
        },
        "interop_config": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/interop_config"
          }
        }
      }
    },
    "service_config_data": {
      "type": "object",
      "properties": {
        "fhir_metadata_set": {
          "type": "string"
        },
        "fhir_version": {
          "type": "string"
        },
        "interactions_strategy_class": {
          "type": "string"
        },
        "default_search_page_size": {
          "type": "integer"
        },
        "max_search_page_size": {
          "type": "integer"
        },
        "max_search_results": {
          "type": "integer"
        },
        "max_conditional_delete_results": {
          "type": "integer"
        },
        "fhir_session_timeout": {
          "type": "integer"
        },
        "default_prefer_handling": {
          "type": "string"
        },
        "debug_mode": {
          "type": "integer"
        }
      }
    },
    "csp_config": {
      "type": "object",
      "properties": {
        "oauth_client_name": {
          "type": "string"
        },
        "service_config_name": {
          "type": "string"
        }
      }
    },
    "interop_config": {
      "type": "object",
      "properties": {
        "service": {
          "type": "string"
        },
        "processes": {
          "type": "string"
        },
        "operation": {
          "type": "string"
        }
      }
    },
    "createTenant": {
      "type": "object",
      "properties": {
        "rootPassword": {
          "type": "string"
        }
      }
    },
    "tenant": {
      "type": "object",
      "properties": {
        "tenantId": {
          "type": "string"
        },
        "endpoints": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/endpoint"
          }
        },
        "pendingEndpoints": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/pendingEndpoint"
          }
        }
      }
    }
  }
}
}

}
