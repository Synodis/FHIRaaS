/// Iris Api to manage tenants<br/>
/// Business logic class defined by OpenAPI in FHIRAAS.API.spec<br/>
/// Updated Aug 28, 2020 09:03:05
Class FHIRAAS.API.impl Extends %REST.Impl [ ProcedureBlock ]
{

/// If ExposeServerExceptions is true, then details of internal errors will be exposed.
Parameter ExposeServerExceptions = 1;

Parameter CONTENTTYPEJSON As %String = "application/json";

Parameter HTTP204NOCONTENT As %String = "204 No Content";

/// Return the list of available tenant on this Iris instance.
ClassMethod getTenants() As %DynamicObject
{
    #dim dyna as %DynamicArray
    set dyna = []

    set tTenant = ""
    While $order(^%SYS("HealthShare","Instances",tTenant))'="" {
        set tTenant = $order(^%SYS("HealthShare","Instances",tTenant))
        if (tTenant'="FHIRAAS") {
            do dyna.%Push(##class(FHIRAAS.Utils.Utils).GetEndpointsByTenant(tTenant))
        }
    }

    Set %response.ContentType = ..#CONTENTTYPEJSON

    Quit dyna
}

/// Returns a tenant by ID.<br/>
/// The method arguments hold values for:<br/>
///     tenantId, the tenant Id<br/>
ClassMethod getTenant(tenantId As %String) As %Stream.Object
{
    set result = ""
    New $namespace
	
    Try {
        $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CheckNameSpace(tenantId))
        
        set result= ##class(FHIRAAS.Utils.Utils).GetEndpointsByTenant(tenantId)

    } Catch Error {

        $$$ThrowOnError(Error.AsStatus())
	}

    Set %response.ContentType = ..#CONTENTTYPEJSON

    Quit result
}

/// Create a tenant with an ID.<br/>
/// The method arguments hold values for:<br/>
///     tenantId, the tenant Id<br/>
///     tenantInformations<br/>
ClassMethod putTenant(tenantId As %String, tenantInformations As %Stream.Object) As %Stream.Object
{
    set sc = $$$OK
	
    Try {
        
        Set namespace=tenantId

        //Install a Foundation namespace and change to it
        set pVars = ""
        set pVars("DBInstallDirectory") = "/external/data/"
        $$$ThrowOnError(##class(HS.HC.Util.Installer).InstallFoundation(namespace,.pVars))

        //Map Interop
        $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).MapFHIRAASForNamespace(namespace))

        //init interop
        $$$ThrowOnError(##class(FHIRAAS.Utils.Interop).Init(tenantId))

        Return ..putEndpoint(tenantId,"endpoint",$g(tenantInformations))
	
	} Catch Error {

        $$$ThrowOnError(Error.AsStatus())
	}

    Quit ""
}

/// Delete a endpoint with an ID.<br/>
/// The method arguments hold values for:<br/>
///     tenantId, the tenant Id<br/>
///     endpointId, the endpoint Id<br/>
ClassMethod deleteEndpoint(tenantId As %String, endpointId As %String) As %Stream.Object
{
    
    $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CheckNameSpace(tenantId))

    New $namespace
    Set $namespace=tenantId

    set delete = 1

    Set appKey = ##class(FHIRAAS.Utils.Utils).GetAppKey(tenantId,endpointId)

    // UnInstall an instance of a FHIR Service into the current namespace
    do ##class(HS.FHIRServer.Installer).UninstallInstance(appKey,delete)

    $$$ThrowOnError(##class(FHIRAAS.Utils.Interop).Delete(endpointId))

    New $Namespace
    Set $Namespace="%SYS"
    set sc = ##class(Security.Users).Delete(tenantId_endpointId)
    set sc = ##class(Security.Roles).Delete("#"_tenantId_endpointId)
    set sc = ##class(Security.Resources).Delete("$"_tenantId_endpointId)

    
    Quit ""
}

/// Delete a tenant with an ID.<br/>
/// The method arguments hold values for:<br/>
///     tenantId, the tenant Id<br/>
ClassMethod deleteTenant(tenantId As %String) As %Stream.Object
{
    $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CheckNameSpace(tenantId))

    set endpointList = ##class(FHIRAAS.Utils.Utils).GetEndpointList(tenantId)

    New $Namespace
    Set $namespace="%SYS"

    Try {

        // Delete users
        set ptr = 0
	    while $listnext(endpointList, ptr, tmp) {
            // Delete Resource, Role, User
            set endpoint = $P(tmp,"/",*)
            set sc = ##class(Security.Users).Delete(tenantId_endpoint)
            set sc = ##class(Security.Roles).Delete("#"_tenantId_endpoint)
            set sc = ##class(Security.Resources).Delete("$"_tenantId_endpoint)
	    }

        // Delete others
        Set count = 0
        Set list = ""
        Set path = ""
        Set tRS = ##class(%Library.ResultSet).%New("Security.Applications:NamespaceList")
        Do tRS.Execute(tenantId)
        While tRS.Next() {
            Set count = count + 1
            if (count > 1) {
                Set list = list_","
                set path = path_","
            }
            Set list = list_tRS.Get("Name")
            Set path = path_tRS.Get("Path")
        }
        do tRS.Close()

		$$$ThrowOnError(##class(Config.Namespaces).Delete(tenantId))

		
		#; clear application 
		If count > 0 {
			For n = 1:1:count {
				Set cspName = $PIECE(list,",",n)
                Set cspPath = $PIECE(path,",",n)
				#; delete csp application from security
				$$$ThrowOnError(##Class(Security.Applications).Delete(cspName))
                #; delete csp pages and physical path
				If (cspPath '= "") {
					#; delete csp pages in this directory
					Set tRS = ##class(%ResultSet).%New("%File:FileSet")
					Do tRS.Execute(cspPath,"*.csp")
					While tRS.Next() {
						Do ##class(%File).Delete(tRS.Get("Name"))
					}
					#; delete this directory - If there are no files left and no subdirectory, then it's deleted.
					Do ##class(%File).RemoveDirectory(cspPath)
				}
			}
		}
		
		#; remove Ensemble namespace
	 	If ((##class(%Library.EnsembleMgr).IsEnsembleInstalled() || ##class(%Library.EnsembleMgr).IsHealthShareInstalled())) {
	 		$$$ThrowOnError(##class(%Library.EnsembleMgr).DisableNamespace($ZCVT(tenantId,"U")))
	 	}

        // Delete the database from the configuration file
        set del = 1
        If del = 1 {

            set dir = ##class(Config.Databases).GetDirectory($TR(tenantId,"%-_","PDU")) 
            $$$ThrowOnError(##class(Config.Databases).Delete($TR(tenantId,"%-_","PDU")))

            // Delete the .DAT file
            $$$ThrowOnError(##class(SYS.Database).DeleteDatabase(dir))

        }

	} Catch Error {

        $$$ThrowOnError(Error.AsStatus())

	}

    Quit ""
}

/// Prints <var>pPayload</var> if it is not empty, else sets the response status to be 'No Content' </br>
ClassMethod EmitResult(pPayload As %DynamicAbstractObject = "") As %DynamicAbstractObject
{
	#dim %response As %CSP.Response
	If pPayload = "" {
		Set %response.Status = ..#HTTP204NOCONTENT
	} Else {
		Set %response.ContentType = ..#CONTENTTYPEJSON
		return pPayload
	}
    Return {}
}

/// Returns a tenant by ID.<br/>
/// The method arguments hold values for:<br/>
///     tenantId, the tenant Id<br/>
///     endpointId, the endpoint Id<br/>
ClassMethod getEndpoint(tenantId As %String, endpointId As %String) As %Stream.Object
{
    $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CheckNameSpace(tenantId))

    New $namespace
    Set $namespace=tenantId

    Set appKey = ##class(FHIRAAS.Utils.Utils).GetAppKey(tenantId,endpointId)

    set result = {}
    set list = ##class(HS.FHIRServer.API.InteractionsStrategy).GetEndpointInfo()
    
    set ptr = 0
    while $listnext(list, ptr, entry) {
        set endpoint = ##class(HS.FHIRServer.Config.RestHandler).SerializeEndpoint($listget(entry, 1))
        if endpoint '= "" {
            set endpoint."interop_config" = ##class(FHIRAAS.Utils.Utils).GetInterfaceMaps(endpointId)
            set:(endpoint.name=appKey) result = endpoint
        }
    }

    #dim pendingEndpoints as %DynamicArray
    set pendingEndpoints = ##class(FHIRAAS.Utils.Utils).ReturnPendingEndpoints(0)
    if pendingEndpoints '= "" {
        set iterator = pendingEndpoints.%GetIterator()
        while iterator.%GetNext(.key,.value) {
        	set:(value.name=appKey) result = value
        }
    }

    Set %response.ContentType = ..#CONTENTTYPEJSON
	return result
}

/// Create a endpoint with an ID.<br/>
/// The method arguments hold values for:<br/>
///     tenantId, the tenant Id<br/>
///     endpointId, the endpoint Id<br/>
///     tenantInformations<br/>
ClassMethod putEndpoint(tenantId As %String, endpointId As %String, tenantInformations As %Stream.Object) As %Stream.Object
{
    $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CheckNameSpace(tenantId))

    New $namespace
    Set $namespace=tenantId

    // Check password
    set password = ""
    if $IsObject($g(tenantInformations)) {
        //Verify payload confirmity against definition
        Set tPaylaod = ##class(FHIRAAS.API.Definition.CreateTenant).%New()
        $$$ThrowOnError(tPaylaod.%JSONImport(tenantInformations))
        set password = tPaylaod.rootPassword

        if password '="" {
            // Create Resouce
		    set tResource = "$"_$Namespace_endpointId
            $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CreateResource(tResource))

            set tRole = "#"_$Namespace_endpointId
            $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CreateRole(tRole,tResource))

            set tUser = $Namespace_endpointId
            $$$ThrowOnError(##class(FHIRAAS.Utils.Utils).CreateUser(tUser,tRole,password))
        }
    }
    

    // Install elements that are required for a FHIR-enabled namespace
    Do ##class(HS.FHIRServer.Installer).InstallNamespace()

    //Install Ui
    do ##class(FHIRAAS.Utils.Utils).InstallUi(tenantId,endpointId)

    //Init default interop
    $$$ThrowOnError(##class(FHIRAAS.Utils.Interop).Add(endpointId))

    Set appKey = ##class(FHIRAAS.Utils.Utils).GetAppKey(tenantId,endpointId)
    Set strategyClass = "HS.FHIRServer.Storage.Json.InteractionsStrategy"
    Set metadataConfigKey = "HL7v40"

    // Install an instance of a FHIR Service into the current namespace
    set jobKey = ##class(HSMOD.REST.Async.API).RunInBackgroundAndReturnJobKey("FHIRAAS.Utils.Utils","InstallInstance",appKey, strategyClass, metadataConfigKey,"",$g(tResource))
    
    Set $namespace="FHIRAAS"
    Set %response.ContentType = ..#CONTENTTYPEJSON
    Return ##class(FHIRAAS.Utils.Utils).GetJob(jobKey)
}

/// Get this spec
ClassMethod getSpec() As %Stream.Object
{
    set pXData = "xdata://FHIRAAS.API.spec:OpenAPI"
    Set tSC = ##class(Ens.Util.URLStream).GetURLStream(pXData,.tStream)
    set swagger = {}.%FromJSON(tStream)
    Do swagger.info.%Remove("x-ISC_Namespace")
    Set swagger.basePath = "/fhiraas/v1"
    Set swagger.info.title = "InterSystems IRIS FHIRAAS"
    Set swagger.info.version = "0.1"
    Set swagger.host = "localhost:52773"
    Return swagger
}

}
