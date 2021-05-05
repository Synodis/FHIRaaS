/// Iris Api to manage tenants
/// Dispatch class defined by RESTSpec in FHIRAAS.API.spec
Class FHIRAAS.API.disp Extends %CSP.REST [ GeneratedBy = FHIRAAS.API.spec.cls, ProcedureBlock ]
{

/// The class containing the RESTSpec which generated this class
Parameter SpecificationClass = "FHIRAAS.API.spec";

/// Ignore any writes done directly by the REST method.
Parameter IgnoreWrites = 1;

/// By default convert the input stream to Unicode
Parameter CONVERTINPUTSTREAM = 1;

/// The default response charset is utf-8
Parameter CHARSET = "utf-8";

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <!-- Get this spec -->
  <Route Url="/tenants/_spec" Method="get" Call="getSpec" />
  <!-- Returns a list of tenants. -->
  <Route Url="/tenants" Method="get" Call="getTenants" Cors="true"/>
  <!-- Returns a tenant by ID. -->
  <Route Url="/tenants/:tenantId" Method="get" Call="getTenant" />
  <!-- Create a tenant with an ID. -->
  <Route Url="/tenants/:tenantId" Method="put" Call="putTenant" />
  <!-- Delete a tenant with an ID. -->
  <Route Url="/tenants/:tenantId" Method="delete" Call="deleteTenant" />
  <!-- Returns a tenant by ID. -->
  <Route Url="/tenants/:tenantId/:endpointId" Method="get" Call="getEndpoint" />
  <!-- Create a endpoint with an ID. -->
  <Route Url="/tenants/:tenantId/:endpointId" Method="put" Call="putEndpoint" />
  <!-- Delete a endpoint with an ID. -->
  <Route Url="/tenants/:tenantId/:endpointId" Method="delete" Call="deleteEndpoint" />
</Routes>
}

/// Get this spec
ClassMethod getSpec() As %Status
{
    Try {
        Set response=##class(FHIRAAS.API.impl).getSpec()
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// Returns a list of tenants.
ClassMethod getTenants() As %Status
{
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/json")
        If '##class(%REST.Impl).%CheckAccepts("application/json") Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts)) Quit
        Set response=##class(FHIRAAS.API.impl).getTenants()
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// Returns a tenant by ID.
ClassMethod getTenant(ptenantId As %String) As %Status
{
    Try {
        Set response=##class(FHIRAAS.API.impl).getTenant(ptenantId)
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// Create a tenant with an ID.
ClassMethod putTenant(ptenantId As %String) As %Status
{
    Try {
        If $isobject(%request.Content) Set ptenantInformations=%request.Content
        Set response=##class(FHIRAAS.API.impl).putTenant(ptenantId,.ptenantInformations)
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// Delete a tenant with an ID.
ClassMethod deleteTenant(ptenantId As %String) As %Status
{
    Try {
        Set response=##class(FHIRAAS.API.impl).deleteTenant(ptenantId)
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// Returns a tenant by ID.
ClassMethod getEndpoint(ptenantId As %String, pendpointId As %String) As %Status
{
    Try {
        Set response=##class(FHIRAAS.API.impl).getEndpoint(ptenantId,pendpointId)
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// Create a endpoint with an ID.
ClassMethod putEndpoint(ptenantId As %String, pendpointId As %String) As %Status
{
    Try {
        If $isobject(%request.Content) Set ptenantInformations=%request.Content
        Set response=##class(FHIRAAS.API.impl).putEndpoint(ptenantId,pendpointId,.ptenantInformations)
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// Delete a endpoint with an ID.
ClassMethod deleteEndpoint(ptenantId As %String, pendpointId As %String) As %Status
{
    Try {
        Set response=##class(FHIRAAS.API.impl).deleteEndpoint(ptenantId,pendpointId)
        Do ##class(FHIRAAS.API.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("FHIRAAS.API.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

}
