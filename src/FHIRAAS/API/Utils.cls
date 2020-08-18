Include (HS.HC, HS.HC.Invoke)

Class FHIRAAS.API.Utils Extends HSMOD.REST.Async.API
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

ClassMethod GetJob(jobKey As %String) As %DynamicObject
{
	set record = ..GetJobRecordFromKey(jobKey)

	set result = {}
	if $IsObject(record){
		set result = ..JobRecordToJson(..GetJobRecordFromKey(jobKey))
	}

    Quit result
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
	set json.type = $Select(jobRecord.MethodName="InstallInstance":"Endpoint",jobRecord.MethodName="InstallFoundation":"Tenant",1:"Other")
	set json.name = $listget(jobRecord.ArgumentList, 1)
	if jobRecord.Result.Size > 0 {
		set json.result = ##class(%DynamicAbstractObject).%FromJSON(jobRecord.Result)
	}
	return json
}

ClassMethod InstallFondation(pNamespace As %String, ByRef pVars, ByRef pLogFile) As %Status [ Private ]
{
	Set tSC = $$$OK
	$$$AddAllRoleTemporary
	Try{
		Set tIsUpgrade=##class(HS.Util.Installer.ConfigItem).GetPropertyValue(pNamespace,"LastActivated")'=""
		Set pVars("Upgrade")=tIsUpgrade
		#dim tComponent as HS.Util.Installer.Foundation
	 	Set pNamespace=$ZCVT(pNamespace,"U")
		set pVars("Type")="Foundation"
		set tSC=##class(HS.Util.Installer.ConfigItem).GetComponentByName(pNamespace,.tComponent,1,"Foundation","HSLIB",.pVars)
		Quit:$$$ISERR(tSC)
		Set pVars("Component")=tComponent
		If $ZCVT(pNamespace,"U")'?1.UN,tComponent.%ClassName(1)'="HS.Util.Installer.Foundation" {
			Set tSC=$$$ERROR($$$GeneralError,"Namespace Name must only contain letters and numbers") Quit
		}
		if $g(pVars("HubEndpoint"))'="" {
			set tComponent.HubEndpoint=$g(pVars("HubEndpoint"))
		}
	 	//do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","tComponent Foundation = "_tComponent.%Id())
		Set tDoMirror=tComponent.%ClassName(1)'="HS.Util.Installer.Foundation"
		Set tSC = ..BuildDBNS(pNamespace,.pVars,.pLogFile,tDoMirror) Quit:$$$ISERR(tSC)
		Do ##class(HS.HC.Util.Installer).MapHSSYSForNamespace(pNamespace)
		Do ##class(HS.HC.Util.Installer).MapHSCUSTOMForNamespace(pNamespace)
		do ##class(HS.HC.Util.Installer).EnableEnsemble("",pNamespace,"",,,,,.pLogFile)
		Set add = ##class(HS.HC.Util.Installer).StandardGlobalMapping()
		do ##class(HS.HC.Util.Installer).AddGlobalMappings(,pNamespace,add,"HSLIB")
		set add="HS,HSMOD,SchemaMap"
		do ##class(HS.HC.Util.Installer).AddClassMappings(,pNamespace,add,"HSLIB")
		//do ##class(HS.HC.Util.Installer).Log(.pLogFile,$$$CurrentClass,$$$CurrentMethod,"Added Package mappings "_add)
		// A bug in Cache?  rINC is mapped with package mapping but rINDEX which is used for IsUpToDate is not
		Set add="HSMOD.*,SchemaMap*"
		do ##class(HS.HC.Util.Installer).AddRoutineMappings(,pNamespace,add,"INC","HSLIB")
		//do ##class(HS.HC.Util.Installer).Log(.pLogFile,$$$CurrentClass,$$$CurrentMethod,"Added include mappings "_add)
		// Save / Reload CPF
		Do ##class(HS.HC.Util.Installer).ActivateConfiguration(,pNamespace)
		Set tCodeDatabase = ..GetInstallerDatabase(.pVars)
		If (tCodeDatabase = "HSLIB") {
			Set tRole = ""
		}
		Else {
			Set tRole = "%DB_" _ tCodeDatabase
		}
		Set tSC = ..BuildPortalApp(pNamespace,.pLogFile,tRole) Quit:$$$ISERR(tSC)
		Set tSC = ..AdditionalSetup(pNamespace,.pVars,.pLogFile) Quit:$$$ISERR(tSC)
		// Ensure ^oddXML is correctly populated for XML classes which extend classes in %SYS and ENSLIB
		set tSC = ##class(HS.HC.Util.Installer).CompileXMLExtensions(pNamespace)
		if $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		//do ##class(HS.HC.Util.Installer).Log(.tLogFile,$$$CurrentClass,$$$CurrentMethod,"Recompiled XML extension classes")
		
		do ##class(HS.FHIRServer.Installer).InstallNamespace(pNamespace)
		set tSC = ##class(HS.HC.Util.Installer.Kit.FHIR.HealthConnect).ImportFHIRGlobals(pNamespace) Quit:$$$ISERR(tSC)
		set tSC = ##class(HS.HC.Util.Installer.Kit.FHIR.HealthConnect).ImportLookupJSON(pNamespace) Quit:$$$ISERR(tSC)
	
		$$$ThrowOnError( ##class(%ZHSLIB.PackageManager.Developer.Utils).AddPackageMapping(pNamespace, "%SYSTEM.Context.HealthShare", tCodeDatabase) )
		set tSC=tComponent.MarkActivated(1) if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		//do ##class(HS.HC.Util.Installer).Log(.tLogFile,$$$CurrentClass,$$$CurrentMethod,"Install "_pNamespace_" done at "_$zdt($h,3))
		//do ##class(HS.HC.Util.Installer).Log(.tLogFile,0) // close logfile
	}
	Catch ex{
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// Generic foundation namespace versus PatientIndex or Analytics, Community
ClassMethod AdditionalSetup(pNamespace, ByRef pVars, ByRef pLogFile) As %Status
{
	Set tSC=$$$OK
	If 'pVars("Upgrade") {
		// Copy in the template as the production, if it does not exist, and (always) compile it
		lock +^HS.Installer.Compile("Production")
		If $G(pVars("Template"))=""||($G(pVars("Template"))="Ens.Production") {
			Do ..CreateProduction(.pVars,.tLogFile,pNamespace)
		} Else {
			set tCopied=##class(HS.HC.Util.Installer).CopyClass(pNamespace,pVars("Template"),pVars("Production"))
			//do ##class(HS.HC.Util.Installer).Log(.tLogFile,$$$CurrentClass,$$$CurrentMethod,$s(tCopied:"Copied & ",1:"")_"Compiled template "_pVars("Template")_" as "_pVars("Production"))
		}
		lock -^HS.Installer.Compile("Production")
		// Add Production Credentials
		// This will NOT overwrite existing credentials
		Set tName=$$$HSServiceUserGetMake
		set:tName]"" tSC = ##class(HS.HC.Util.Installer).SetCredential(pNamespace,tName,tName,tName,0) if $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		//do ##class(HS.HC.Util.Installer).Log(.tLogFile,$$$CurrentClass,$$$CurrentMethod,"Set Credential "_tName)
	}
	// Map HS.Doc.Data.* globals for SDA/CDA Annotations to HSSYS for Foundation namespaces.
	Set tSC = ##class(HS.Doc.Utility.Setup).Mapping(pNamespace)
	If $$$ISERR(tSC) Quit tSC
	
	Set tSC = ##class(HS.Util.Installer.Kit.Base).PostInstallItems(pNamespace,"Foundation",$S(pVars("Upgrade"):"Upgrade",1:"New"))
	If $$$ISERR(tSC) Quit tSC
	Quit tSC
}

/// Build CSP application
ClassMethod BuildPortalApp(pNamespace, ByRef pLogFile, pAddRoles As %String = "") As %Status
{
	try {
		Set tInitialNS=$namespace
		New $namespace
		Set tSC = $$$OK
		Set DBResource=..GetDBResourceName(pNamespace)
		Set $Namespace="HSLIB"
		Set tHSRole = "%HS_"_$e(DBResource,2,*)
		Set tCSPRoles=tHSRole_",%DB_HSLIB,%HS_DB_HSSYS,%DB_HSCUSTOM"
		Set tSC = ..CreateCSPRoles(tCSPRoles) Quit:$$$ISERR(tSC)
		Set:pAddRoles'="" tCSPRoles=tCSPRoles_","_pAddRoles
		Set tCSPSessionEventsClass = ##class(HS.Util.Installer.ConfigItem).GetDefaultCSPSessionEventsClassForNamespace(pNamespace)
		Set tNsp=$tr($zcvt(pNamespace,"L"),"%")
		Set tURL="/csp/healthshare/"_tNsp,tServiceURL=tURL_"/services"
		// Note: This does not update an existing application !
		Set tSC = ##class(HS.Util.SystemAPI).Invoke("CreateCSPApp",pNamespace,1,tURL,$tr(pNamespace,"%"),..CSPPath(tNsp),"HealthShare Foundation Portal",tCSPRoles,"/csp/healthshare",,tCSPSessionEventsClass)
		$$$ThrowOnError(tSC)
		Set tSC = ##class(HS.Util.SystemAPI).Invoke("CreateCSPApp",pNamespace,0,tServiceURL,$tr(pNamespace,"%"),..CSPPath(tNsp),"HealthShare Foundation Services",tCSPRoles,"/csp/healthshare",,,1)
		$$$ThrowOnError(tSC)
		//do ##class(HS.HC.Util.Installer).Log(.pLogFile,$ClassName(),"Install","Created Portal CSP app")
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod CreateCSPRoles(pNames) As %Status
{
	Set tSC=$$$OK
	For i=1:1:$l(pNames,",")
	{
		Set tName=$p(pNames,",",i)
		Set tResourceDB = $p(tName,"_",3)
		Continue:tResourceDB=""  // we're only processing ones like %HS_DB_someDatabase
		Set tResource = "%DB_"_tResourceDB_":RWU"
		Set tSC=##class(HS.Util.SystemAPI).Invoke("AddUpdateRole",tResourceDB,tName,"",tResource)
		Quit:$$$ISERR(tSC)
	}
	Quit tSC
}

ClassMethod BuildDBNS(pNamespace, ByRef pVars, ByRef pLogFile, pDoMirror As %Boolean = 1) As %Status
{
	try {
		new $namespace
		Set tSC = $$$OK
		Set $namespace="%SYS"
	 	// Check if pNamespace already exists
		Set tExists=##Class(Config.Namespaces).Exists(pNamespace)
		Set $namespace="HSLIB"
		Quit:tExists
		Set tDBName = $TR(pNamespace,"%-_","pdu")
		set DBResource="%DB_"_$ZCVT(tDBName,"U")

		If $Data(pVars("DBInstallDirectory"),tValue)#2 && (tValue '= "") {
			Set tDataDir = ##class(%File).NormalizeDirectory(tValue)
		}

		// Create the IRIS.DAT (if not already there)
		If $G(pVars("FromEnableEnsemble"))'=1 {
			//This gets set by %ZHSLIB.HealthShareMgr - the DB already exists, and might be mixed case
			//do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","About to Create Database "_tDBName)
			If $system.Mirror.IsMember() do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","Database Create must wait for all mirror members")
			Set tSC=##class(HS.Util.SystemAPI).CreateDatabase(tDBName, pDoMirror, .tDataDir) Quit:$$$ISERR(tSC)
			//do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","Create "_$$$DatabaseFilename_" in "_tDataDir_tDBName)
		}

		// Create the Namespace (if not already there)
		Set tSC=##class(HS.Util.SystemAPI).Invoke("CreateNamespace",tDBName,pNamespace,tDBName,tDBName) Quit:$$$ISERR(tSC)
		//do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","Made Namespace "_pNamespace)
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Return the database from which installer-related activities should be performed.
ClassMethod GetInstallerDatabase(ByRef pVars, pProduct As %String = "") As %String [ Internal ]
{
	Quit "HSLIB"
}

ClassMethod CreateProduction(ByRef pVars, ByRef pLogFile, pNamespace) As %Status
{
	New $namespace
	Set $namespace=pNamespace
	set tSC=..GetComponentByName(pNamespace,.pComponent,1,pVars("Type"),"HSLIB",.pVars) Quit:$$$ISERR(tSC)
	set tProduction=$g(pVars("Production"))
	if tProduction="" {
		set tProduction=pComponent.Production
		if tProduction="" {
			set tProduction=pComponent.GetProductionName()
		}
	}
	Set tProduction=$tr(tProduction,"%_")
	set (pComponent.Production,pVars("Production"))=tProduction

	Set tClass=##class(%Dictionary.ClassDefinition).%New(pVars("Production"))
	Set tClass.Super="Ens.Production"
	Set tXData = ##class(%Dictionary.XDataDefinition).%New()
	Set tXData.Name="ProductionDefinition"
	Do tXData.Data.Write("<Production Name="""_pVars("Production")_""" LogGeneralTraceEvents=""false""></Production>")	
	Do tClass.XDatas.Insert(tXData)
	Set tSC = tClass.%Save()
	Set tSC= $system.OBJ.Compile(pVars("Production"),"fck-dv")
	//do ##class(HS.HC.Util.Installer).Log(.tLogFile,$$$CurrentClass,$$$CurrentMethod,"Compiled template "_pVars("Production"))
	Set ^Ens.Configuration("csp","LastProduction")=pVars("Production")
}

/// Open the configuration object pComponent with name pName
/// If it does not exist (an pCreate is set) then create an object of the specified type,
///  using any Settings provided and some (but not all) defaults
/// pHSLIB argument is not used - it's an ancient leftover
ClassMethod GetComponentByName(pName As %String, ByRef pComponent As HS.Util.Installer.ConfigItem, pCreate As %Boolean = 0, pType As %String = "", pHSLIB As %String = "HSLIB", ByRef pSettings) As %Status
{
	new $namespace
	set tSC=$$$OK,$ZT="Trap"
	do {
		Set pComponent = ""
		// Component names should be uppercase
		New $Namespace Set $Namespace="HSLIB"
		set pName=$ZCVT(pName,"U")
		&sql(SELECT ID INTO :tID FROM HS_Util_Installer.ConfigItem 
			WHERE Name=:pName)
		if SQLCODE=0 {
			// Found it ...
			set pComponent=##class(HS.Util.Installer.ConfigItem).%OpenId(tID,,.tSC)
			Quit:$$$ISERR(tSC)
			Quit:pType=""
			Quit:(pType="Foundation" && (pComponent.%Extends("HS.Util.Installer.Foundation")))
			If ($classname(pComponent) = ("HS.Util.Installer."_pType)) || (pComponent.GetConfigTypeName() = pType) || ($classname(pComponent) = pType) {
				Quit
			}
			set tSC = $$$HSError($$$HSErrComponentWrongType,pName,pType)
			quit
		} elseIf SQLCODE=100 {
			// Not found ...
			if pCreate {
				If $G(pSettings("FoundationTypeClass")) ] "" {
					set tClass=pSettings("FoundationTypeClass")
				}
				ElseIf $G(pSettings("FoundationType"))]"" {
					set tClass="HS.Util.Installer."_pSettings("FoundationType")
				} Else {
					set tClass="HS.Util.Installer."_pType
				}
				if ##class(%Dictionary.CompiledClass).%ExistsId(tClass) {					
					if $classmethod(tClass,"%IsA","HS.Util.Installer.ConfigItem") {					
						set pComponent=$ZOBJCLASSMETHOD(tClass,"%New")
						set pComponent.Name=pName
						set pComponent.%HSLIB="HSLIB"
						//set pComponent.Production=pName_"."_pType_"Production"
						set pComponent.Production=pComponent.GetProductionName()
						// Apply any settings
						if $d(pSettings) {
							set tSetting="" for {
								set tSetting=$ORDER(pSettings(tSetting)) quit:tSetting=""
								try {
									set $ZOBJPROPERTY(pComponent,tSetting)=pSettings(tSetting)
								} Catch {}
							}
						}						
						set tSC = pComponent.%Save()
					}
					else {
						set tSC = $$$ERROR($$$HSErrComponentWrongType, pName, tClass)
					}
				} else {
					set tSC = $$$HSError($$$HSErrUnknownComponentType,tClass)
				}
			} else {
				set tSC = $$$HSError($$$HSErrComponentDoesNotExist,pName)
			}
		} else {
			// Some other error ...
			Set tSC = $$$ERROR($$$SQLError,SQLCODE,$G(%msg))
		}
	} While (0)
Exit
	quit tSC
Trap
	Do LOG^%ETN
	set tSC = $$$ERROR($$$ObjectScriptError,$ZE)
	goto Exit
}

ClassMethod GetDBResourceName(pNamespace As %String = "", ByRef tSC = {$$$OK}) As %String
{
	Set tResource=""
	try {
		New $namespace
		Set $Namespace="%SYS"
		Set tCfgNS=##Class(Config.Namespaces).Open(pNamespace)
		Set tCfgDB = ##class(Config.Databases).Open(tCfgNS.Globals)
		Set tObjDB=##class(SYS.Database).%OpenId(tCfgDB.Directory)
		Set tResource=tObjDB.ResourceName
	} catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tResource
}

ClassMethod CSPPath(pNamespace) As %String
{
	Set pNamespace=$translate($zconvert(pNamespace,"L"),"%")
	If $$$isUNIX Quit "\csp\healthshare\"_pNamespace_"\"
	Quit "\CSP\healthshare\"_pNamespace_"\"
}

}