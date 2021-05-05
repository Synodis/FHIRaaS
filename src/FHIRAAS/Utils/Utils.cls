Include (HS.HC, HS.HC.Invoke, HS.FHIRServer, HSMOD.REST.Async)

Class FHIRAAS.Utils.Utils
{

ClassMethod GetJobs() As %DynamicObject
{
	set records = ..GetJobRecords()
	
	set openJobs = []
	for i=1:1:records.Count() {
		set record = records.GetAt(i)
		do openJobs.%Push(..JobRecordToJson(record))

	}
    
    Quit openJobs
}

/// Returns all available instances of <class>HSMOD.REST.Async.JobRecord</class> based on the
/// provided search criteria. <br />
/// @Argument	pSearchCriteria			Key-value pairs of search criteria. <br />
ClassMethod GetJobRecords(pSearchCriteria As %Library.DynamicObject) As %Library.ListOfObjects(ELEMENTTYPE="HSMOD.REST.Async.JobRecord")
{
	Set jobRecordList = ##class(%Library.ListOfObjects).%New()
	// TODO: Use search criteria
	#dim resultSet As %SQL.StatementResult
	Set query = "SELECT ID FROM HSMOD_REST_Async.JobRecord"
	Set statement = ##class(%SQL.Statement).%New()
	$$$ThrowOnError(statement.%Prepare(query))
	Set resultSet = statement.%Execute()
	If (resultSet.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(resultSet.%SQLCODE, resultSet.%Message)
	}
	While resultSet.%Next(.sc) {
		$$$ThrowOnError(sc)
		Set id = resultSet.ID
		Set jobRecord = ##class(HSMOD.REST.Async.JobRecord).%OpenId(id, , .sc)
		$$$ThrowOnError(sc)
		$$$ThrowOnError(jobRecordList.Insert(jobRecord))
	}
	$$$ThrowOnError(sc)
	Return jobRecordList
}

/// Returns an instance of <class>HSMOD.REST.Async.JobRecord</class> that is uniquely
/// referenced by <var>pKey</var>.
/// Returns a null oref if no object found. <br />
/// @API.Method <br />
/// @Argument	pKey		Unique reference to an instance of <class>HSMOD.REST.Async.JobRecord</class>. <br />
ClassMethod GetJobRecordFromKey(pKey As %String) As HSMOD.REST.Async.JobRecord [ Internal ]
{
	Set id = ##class(HSMOD.REST.Async.Utils).GetJobIdFromJobKey(pKey)
	If '##class(HSMOD.REST.Async.JobRecord).%ExistsId(id) {
		Return $$$NULLOREF
	}
	Set jobRecord = ##class(HSMOD.REST.Async.JobRecord).%OpenId(id, , .sc)
	$$$ThrowOnError(sc)
	Return jobRecord
}

ClassMethod GetJob(jobKey As %String) As %DynamicObject
{
	set record = ..GetJobRecordFromKey(jobKey)

	set result = {}
	if $IsObject(record){
		set result = ..JobRecordToJson(..GetJobRecordFromKey(jobKey))
	}

    Quit result
}

ClassMethod MapFHIRAASForNamespace(pNS, pActivate = 1) As %Status
{
	try {
		Set tSC=$$$OK
		Set tSC=##class(HS.HC.Util.Installer).AddClassMappings("",pNS,"FHIRAAS,Interop,User","FHIRAAS")
		Quit:$$$ISERR(tSC)
		Do:pActivate ##class(HS.HC.Util.Installer).ActivateConfiguration(,pNS)
	} Catch ex {
		Set tSC= ex.AsStatus()
	}
	Quit tSC
}

ClassMethod CheckNameSpace(tenantId) As %Status
{
	new $Namespace
	set $Namespace="%SYS"
	return ##Class(Config.Namespaces).Get(tenantId)
}

ClassMethod GetAppKey(tenantId As %String, endpointId As %String) As %String
{
	Return "/v1/fhiraas/"_$zcvt(tenantId,"L")_"/fhir/r4/"_endpointId
}

ClassMethod CreateResource(pResource As %String) As %Status
{
	Quit ##class(HS.Util.SystemAPI).Invoke("AddUpdateResource",$Namespace,pResource,"","")
}

ClassMethod CreateRole(pRole As %String, pResource As %String) As %Status
{
	Quit ##class(HS.Util.SystemAPI).Invoke("AddUpdateRole",$Namespace,pRole,"",pResource_":RWU","")
}

ClassMethod InstallUi(tenantId As %String, endpoint As %String) As %Status
{

	SET args=2
  	SET args(1)="/opt/irisapp/ui/install.sh"
	SET args(2)=$zcvt(tenantId,"L")
  	SET args(3)=$zcvt(endpoint,"L")
  	SET status = $ZF(-100,"", "sh",.args)

	Quit status
}

ClassMethod GetInterfaceMaps(endpoint As %String = "") As %DynamicObject
{
	Set out = []
	Set tResult = ##class(%Library.ResultSet).%New("Ens.InterfaceMaps.Utils:EnumeratePaths")
	do tResult.Execute(endpoint)
	while tResult.%Next() {
		set tmp = {}
		set tmp.service = tResult.%Get("Service")
		set tmp.processes = tResult.%Get("Processes")
		set tmp.operation = tResult.%Get("Operation")
		do out.%Push(tmp)
	}

	Return out
}

ClassMethod CreateUser(pUser As %String, pRole As %String, pPassword As %String) As %Status
{
	Set tSC=$$$OK
	Try {
		Set tUser = pUser,tUserFullName="FHIRaaS User"
		Set tRole = pRole

		new $namespace
		set $namespace="%SYS"
		
		If '##class(Security.Users).Exists(tUser,.User) {
			Set tEnabled = 1
			Set tSC=##Class(Security.Users).Create(tUser,tRole,pPassword,tUserFullName,,,,,tEnabled,,,,,,1,1)
			$$$ThrowOnError(tSC)
		} Else {
			Set User.Enabled = 1
			Set tSC=User.%Save() 
			$$$ThrowOnError(tSC)
		}

	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

ClassMethod GetEndpointsByTenant(tenantId As %String) As %DynamicObject
{
    New $namespace
    Set $namespace=tenantId

    set result = {}
    set result.tenantId = tenantId
    set endpoints = []
    set list = ##class(HS.FHIRServer.API.InteractionsStrategy).GetEndpointInfo()
    
    set ptr = 0
    while $listnext(list, ptr, entry) {
        set endpoint = ##class(HS.FHIRServer.Config.RestHandler).SerializeEndpoint($listget(entry, 1))
        if endpoint '= "" {
			set endpoint."interop_config" = ##class(FHIRAAS.Utils.Utils).GetInterfaceMaps()
            do endpoints.%Push(endpoint)
        }
    }
    set result.endpoints = endpoints


    set pendingEndpoints = ##class(FHIRAAS.Utils.Utils).ReturnPendingEndpoints(1)
    if pendingEndpoints '= "" {
        set result.pendingEndpoints = pendingEndpoints
    } else {
        set result.pendingEndpoints = []
    }

	return result
}

ClassMethod GetEndpointList(tenantId) As %List
{
	new $Namespace
    set $Namespace=tenantId

    // Get list endpoint for deleting users
	quit ##class(HS.FHIRServer.ServiceAdmin).GetEndpointList()
}

ClassMethod CleanCompleted() As %Status
{
	set records = ..GetJobRecords()
	
	set openJobs = []
	for i=1:1:records.Count() {
		set record = records.GetAt(i)

		if (record.Status = $$$JobComplete) {
			$$$ThrowOnError(##class(HSMOD.REST.Async.JobRecord).%DeleteId(record.%Id()))
			continue
		}

	}

	Quit $$$OK
}

ClassMethod CleanJobs() As %Status
{
	set records = ..GetJobRecords()
	
	set openJobs = []
	for i=1:1:records.Count() {
		set record = records.GetAt(i)

		$$$ThrowOnError(##class(HSMOD.REST.Async.JobRecord).%DeleteId(record.%Id()))

	}

	Quit $$$OK
}

ClassMethod CleanJob(jobKey As %String) As %Status
{
	set record = ..GetJobRecordFromKey(jobKey)

	set result = {}
	if $IsObject(record){
		$$$ThrowOnError(##class(HSMOD.REST.Async.JobRecord).%DeleteId(record.%Id()))
	}

	Quit $$$OK
}

ClassMethod AddJob(pClassname As %Dictionary.CacheClassname, pMethodName As %Dictionary.CacheIdentifier, pArguments...) As %DynamicObject
{
	set jobKey = ##class(HSMOD.REST.Async.API).RunInBackgroundAndReturnJobKey(pClassname, pMethodName, pArguments... )
	Quit ..GetJob(jobKey)
}

ClassMethod JobRecordToJson(jobRecord As HSMOD.REST.Async.JobRecord) As %DynamicObject
{
	set json = {}
	set json."job_key" = jobRecord.JobKey
	set json.status = jobRecord.Status
	set json.type = $Select(jobRecord.MethodName="InstallInstance":"endpoint",jobRecord.MethodName="InstallFoundation":"tenant",1:"Other")
	set json.name = $listget(jobRecord.ArgumentList, 1)
	if jobRecord.Result.Size > 0 {
		set json.result = ##class(%DynamicAbstractObject).%FromJSON(jobRecord.Result)
	}
	return json
}

ClassMethod InstallInstance(pAppKey As %String, pStrategyClass As %String, pMetadataSetKey As %String, pOAuthClientName As %String = "", pResource As %String)
{
	try {
		// Ensure we can get a metadataSet
		Set metadataSet = ##class(HS.FHIRServer.FHIRMetadataSet).%OpenId(pMetadataSetKey)
		if '$isobject(metadataSet) {
			$$$ThrowFHIR($$$GeneralError, "Metadata set does not exist '" _ pMetadataSetKey _ "'")
		}
		Set strategyKey = $parameter(pStrategyClass, "StrategyKey")
		
		// Validate form if App Key
		if ($E(pAppKey) '= "/") || ($E(pAppKey,*) = "/" ) {
			$$$ThrowFHIR($$$GeneralError, "AppKey must begin with a slash and must NOT end with a slash")
		}
		
		if ##class(HS.FHIRServer.ServiceAdmin).EndpointExists(pAppKey) {
			$$$ThrowFHIR($$$GeneralError, "There is already an instance installed for endpoint " _ pAppKey)
		}
		
		//Only build metadata globals if they don't exist. If a different endpoint is also using
		//this metadata set, we don't want to change that endpoint's behavior if the metadata has
		//changed.
		if '$data($$$FSMetaGlobal(metadataSet.Key)) {
			w "Loading Metadata into Globals",!
			Do ##class(HS.FHIRServer.Tools.FHIRMetadataSetLoader).BuildGlobals(metadataSet.Key)
		}

		// Create the CSP Application
		Set tNS = $Namespace
		
		// If an CSP app already exists for this app key and namespace, then
		// update only a few of the properties and carry over existing values
		// for the rest.
		Set tCSPAppExists = ##class(HS.FHIRServer.Installer).CSPAppExists(pAppKey, .appObj)
		// Security.Application object property name is NameSpace, not Namespace.
		If (tCSPAppExists) && (appObj.NameSpace'=tNS) {
			$$$ThrowFHIR($$$GeneralError, "CSP app "_pAppKey_" already exists for another namespace ("_appObj.NameSpace_")")
		}
		
		// These items definitely need to be set/changed to these values.
		Set tProps("Name") = pAppKey
		Set tProps("NameSpace") = tNS
		Set tProps("DispatchClass") = "HS.FHIRServer.RestHandler" 
		Set tProps("AutheEnabled") = ($$$AutheUnauthenticated + $$$AutheCache + $$$AutheDelegated)
		Set tProps("Description") = "FHIR Server end point; strategy=" _ strategyKey _ ", metadataSet=" _ pMetadataSetKey
		Set tProps("MatchRoles") = ":%HS_DB_"_$tr(tNS,"%")_":%DB_HSLIB:%DB_HSSYS"
		
		If tCSPAppExists {
			For name = "Timeout", "InbndWebServicesEnabled", "AutoCompile", "IsNameSpaceDefault", "DeepSeeEnabled", "GroupById", "CSPZENEnabled", "UseCookies", "CookiePath" {
				Set tProps(name) = $Property(appObj, name)
			}
		} Else {
			Set tProps("Timeout") = 900
			Set tProps("InbndWebServicesEnabled") = 0
			Set tProps("AutoCompile") = 0
			Set tProps("IsNameSpaceDefault") = 0
			Set tProps("UseCookies") = 0
			Set tProps("DeepSeeEnabled") = 0
			Set tProps("GroupById") = ""
			Set tProps("CookiePath") = ""
			Set tProps("CSPZENEnabled") = 1
			Set:($g(pResource)'="") tProps("Resource") = pResource
		}
		Set tSC=##class(HS.Util.SystemAPI).Invoke("UpdateCSPApp",tNS,pAppKey,$$$NVPairToList(tProps),1,"n")
		$$$ThrowOnError( tSC )

		// Create the App Config Persistent object
		Set restConfigObj = ##class(HS.Util.RESTCSPConfig).URLIndexOpen(pAppKey)
		If '$IsObject($Get(restConfigObj)) {
			Set restConfigObj = ##class(HS.Util.RESTCSPConfig).%New()
			Set restConfigObj.ServiceConfigName = "HS.FHIRServer.Interop.Service"
			Set restConfigObj.URL = pAppKey
		}
		if pOAuthClientName'="" {
			Set restConfigObj.OAuthClientName = pOAuthClientName
		}
		$$$ThrowOnError( restConfigObj.%Save() )
		
		
		#dim serviceInstance as HS.FHIRServer.ServiceInstance
		#dim strategy as HS.FHIRServer.API.InteractionsStrategy
		Set serviceInstance = ##class(HS.FHIRServer.ServiceInstance).NewInstance(pStrategyClass, metadataSet.Key)
		Set strategy = serviceInstance.CreateStrategy()


		// Create the FHIRService Configuration Object
		#dim configData as HS.FHIRServer.API.ConfigData = ##class(HS.FHIRServer.Tools.ConfigEditor).NewDefaultConfig()
		
		Set configData.DebugMode = 0
		Set:($g(pResource)="") configData.DebugMode = 4
		Set configData.FHIRVersion = metadataSet.FHIRVersion
		Set configData.FHIRMetadataSet = metadataSet.Key
		Set configData.InteractionsStrategyClass = pStrategyClass
		
		// Save an initial Configuration Object
		Do strategy.SaveServiceConfigData(configData)
		
		// Create the persistent classes
		Set options("restURL") = pAppKey
		Do strategy.Create(.options)
		
		// Create a CapabilityStatement
		Set interactions = strategy.NewInteractionsInstance()
		do interactions.SetMetadata( strategy.GetMetadataResource() )
	} catch ex {

		throw ex
	}
	// Success, Commit any changes
	
}

ClassMethod ReturnPendingEndpoints(clearCompleted As %Boolean, name As %String = "", interactionsStrategyClass As %String = "", metadataSet As %String = "") As %DynamicArray
{
	set records = ..GetJobRecords()
	
	set openJobs = []
	for i=1:1:records.Count() {
		set record = records.GetAt(i)
		if (record.Namespace '= $namespace) {
			continue
		}
		if clearCompleted && (record.Status = $$$JobComplete) {
			$$$ThrowOnError(##class(HSMOD.REST.Async.JobRecord).%DeleteId(record.%Id()))
			continue
		}
		
		//If name is present and matches, add, regardless of whether anything else
		//matches
		if name '= "" {
			if $listget(record.ArgumentList, 1) = name {
				do openJobs.%Push(..JobRecordToJson(record))
				continue
			}
		}
		
		//If interactions strategy and/or metadata set are provided, only
		//add to the result set if they (both) match
		if interactionsStrategyClass '= "" {
			if $listget(record.ArgumentList, 2) '= interactionsStrategyClass {
				continue
			}
		}
		if metadataSet '= "" {
			if $listget(record.ArgumentList, 3) '= metadataSet {
				continue
			}
		}
		
		do openJobs.%Push(..JobRecordToJson(record))
		
		if clearCompleted && ((record.Status = $$$JobError) || (record.Status = $$$JobInternalError)) {
			$$$ThrowOnError(##class(HSMOD.REST.Async.JobRecord).%DeleteId(record.%Id()))
		}
	}
	if openJobs.%Size() = 0 {
		return ""
	}
	
	return openJobs
}

}
