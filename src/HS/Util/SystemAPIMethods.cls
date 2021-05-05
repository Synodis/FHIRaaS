Include %ZHSLIB

/// Methods that can be invoked by internal API calls to ##class(HS.Util.SystemAPI).Invoke
Class HS.Util.SystemAPIMethods [ Abstract ]
{

/// Should only be used in deleting a database that's not part of a namespace
ClassMethod DeleteDatabase(pDatabaseName As %String) As %Status [ Internal ]
{
	try {
		Set tSC = $$$OK
		New $namespace
		Set $namespace="%SYS"
		Set tSC=..UnMirrorDatabase(pDatabaseName) Quit:$$$ISERR(tSC)
		set tMgrDir=$system.Util.ManagerDirectory()
		set tDataDir=##class(%File).NormalizeDirectory(tMgrDir_"/"_pDatabaseName)
		//set tSC = $$DeleteDatabase^%SYS.DATABASE(tDataDir)
		Set tSC=##class(Config.Databases).Delete(pDatabaseName) Quit:$$$ISERR(tSC)
		Set tSC=##class(SYS.Database).DeleteDatabase(tDataDir)
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// The databases need to already exist
/// Before doing this, for a regular HealthShare config item database, we expect the config item
/// to be defined.
/// This should be immediately followed by a call to CreateCSPApp, Ensemble mapping, etc.
ClassMethod CreateNamespace(pNamespace As %String, pCodeDB = "", pDataDB = "") As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Set pNamespace=$ZCVT(pNamespace,"U")
		If $TR(pNamespace,"-_%","")'?1.UN Set tSC=$$$ERROR($$$GeneralError,"Namespace must only contain letters, numbers, and -_%") Quit
		Set:pCodeDB="" pCodeDB = pNamespace
		Set:pDataDB="" pDataDB = pNamespace
		New $namespace
		Set $namespace="%SYS"
	 	// Check if pNamespace already exists
		Quit:##Class(Config.Namespaces).Exists(pNamespace)
		kill p set p("Globals")=pDataDB,p("Routines")=pCodeDB
		set tSC=##Class(Config.Namespaces).Create(pNamespace,.p)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// If the CSP portal has not been set up for Ensemble, along with Ensemble mappings,
/// this will only delete the namespace.
/// Otherwise, this will also delete the core databases that belong to that namespace,
/// the primary database roles & resources, as well as the primary CSP portal.
/// If pDeleteCSPApps is set, this will delete additional CSP apps.
/// This does not delete any additional roles & resources,
/// or the HealthShare Config item.
ClassMethod DeleteNamespace(pNamespace As %String, pPurgeFiles As %Boolean = 1, pDeleteCSPApps As %Boolean = 0) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Set pNamespace=$ZCVT(pNamespace,"U")
		Set tSC=..UnMirrorDatabase(pNamespace) Quit:$$$ISERR(tSC)
		If ##class(%EnsembleMgr).DetermineMgmtURLForNamespace(pNamespace)="" {
			New $Namespace
			Set $Namespace="%SYS"
			Set tSC=##Class(Config.Namespaces).Delete(pNamespace) Quit
		}
		set tSC=##class(%EnsembleMgr).deleteNamespace(pNamespace,pPurgeFiles,1,,1)
		Quit:$$$ISERR(tSC)
		if pDeleteCSPApps {
			set tSC = ##class(%ZHSLIB.PackageManager.Developer.Build).DeleteWebApplications(pNamespace)
			Quit:$$$ISERR(tSC)
		}
		//This will Kill ^%SYS("HealthShare","Instances",pNamespace)
		set tSC = ##class(%EnsembleMgr).DisableNamespace(pNamespace,1)
	}Catch ex {
		Set tSC = ex.AsStatus()
	}
	Kill ^%SYS("Ensemble","InstalledNamespace",pNamespace)
	Quit tSC
}

/// Internal Utility Method
/// Assumes that databases live in the standard place
ClassMethod UnMirrorDatabase(pDatabaseName) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Quit:'$system.Mirror.IsMember()
		New $Namespace
		Set $Namespace="%SYS"
		set tMgrDir=$system.Util.ManagerDirectory()
		set tDataDir=##class(%File).NormalizeDirectory(tMgrDir_"/"_pDatabaseName)
		set tDbObj=##class(SYS.Database).%OpenId(tDataDir,,.tSC2) Quit:$$$ISERR(tSC2)  //ok if db doesn't exist
		Quit:'tDbObj.Mirrored
		Quit:'tDbObj.Mounted
		Set tSC=##class(SYS.Mirror).RemoveMirroredDatabase(tDataDir)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// Ensures that the provided database is the correct system level database (CACHE vs IRIS).
/// If the provided database is not a system level database it is returned as is. <br />
/// @Argument	pDatabase		Given database. <br />
ClassMethod GetCorrectedDatabase(pDatabase As %String) As %String [ Final, Internal, Private ]
{
	// *LIB, *SYS, *TEMP are the ONLY system level databases
	Return $Case($ZConvert(pDatabase, "U"),
		"CACHELIB": "IRISLIB",
		"CACHESYS": "IRISSYS",
		"CACHETEMP": "IRISTEMP",
		: pDatabase
	)
}

/// Add a list of class/package mappings
/// Adds them to the current configuration, but does not activate
/// pNamespace is the current namespace being configured, where the classes are to be used
/// pAddList is a comma-list of package specs, like "HS*,web*,..."
/// pFrom is the database containing the package
/// The mappings are assumed to not exist, use DeleteClassMappings to remove them first (to get correct order!)
ClassMethod AddClassMappings(pNamespace As %String, pAddList As %String, pFrom As %String) As %Status [ Internal ]
{
	Set pFrom = ..GetCorrectedDatabase(pFrom)
	New $namespace
	Set $namespace="%SYS"
	// For each entry in the addlist, add it
	kill p set p("Database")=pFrom
	for i=1:1:$l(pAddList,",") {
		set tPkg=$p(pAddList,",",i)
		if '##Class(Config.MapPackages).Exists(pNamespace,tPkg) {
			set tSC=##Class(Config.MapPackages).Create(pNamespace,tPkg,.p,,1) // save only
			if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
	}
	Quit $$$OK
}

/// Remove a list of class/package mappings for the selected Namespace
ClassMethod DeleteClassMappings(pNamespace As %String, pDeleteList As %String = "") As %Status [ Internal ]
{
	New $namespace
	Set $namespace="%SYS"
	// For each entry in the deletelist, clear it
	for i=1:1:$l(pDeleteList,",") {
		set tPkg=$p(pDeleteList,",",i)
		if ##Class(Config.MapPackages).Exists(pNamespace,tPkg) {
			set tSC=##Class(Config.MapPackages).Delete(pNamespace,tPkg) if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
	}
	Quit $$$OK
}

/// Add a list of routine mappings of specified type ("ALL", "INC", etc)
/// Adds them to the current configuration, but does not activate
/// pNamespace is the current namespace being configured, where the routines are to be used
/// pAddList is a comma-list of routine specs, like "A*,BA*,..."
/// pType is the type to map, "ALL" or "INC"
/// pFrom is the database containing the routines
/// The mappings are assumed to not exist, use DeleteRoutineMappings to remove them first
ClassMethod AddRoutineMappings(pNamespace As %String, pAddList As %String, pType As %String = "ALL", pFrom As %String) As %Status [ Internal ]
{
	Set pFrom = ..GetCorrectedDatabase(pFrom)
	New $namespace
	Set $namespace="%SYS"
	kill p set p("Database")=pFrom
	for i=1:1:$l(pAddList,",") {
		set tRtn=$p(pAddList,",",i)_$S(pType="ALL":"",1:"_"_pType)
		if '##Class(Config.MapRoutines).Exists(pNamespace,tRtn) {
			set tSC=##Class(Config.MapRoutines).Create(pNamespace,tRtn,.p,,1) // save only
			if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
	}
	Quit $$$OK
}

/// Remove a list of routine mappings of specified type ("ALL", "INC", etc)
ClassMethod DeleteRoutineMappings(pNamespace As %String, pDeleteList As %String = "", pType As %String = "ALL") As %Status [ Internal ]
{
	New $namespace
	Set $namespace="%SYS"
	// For each entry in the deletelist, clear it
	for i=1:1:$l(pDeleteList,",") {
		set tRtn=$p(pDeleteList,",",i)
		// There was a bug in early 2009.1 that (eg) TRAK.inc was stored as "TRAK" rather then "TRAK_INC"
		// Make sure we delete this if it exists, else the Add will fail
		if ##Class(Config.MapRoutines).Exists(pNamespace,tRtn) {
			set tSC=##Class(Config.MapRoutines).Delete(pNamespace,tRtn) if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
		// Now the permanent code:
		set tRtn=$p(pDeleteList,",",i)_$S(pType="ALL":"",1:"_"_pType)
		if ##Class(Config.MapRoutines).Exists(pNamespace,tRtn) {
			set tSC=##Class(Config.MapRoutines).Delete(pNamespace,tRtn) if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
	}
	Quit $$$OK
}

/// Add a list of global mappings of specified type
/// Adds them to the current configuration, but does not activate
/// pNamespace is the current namespace being configured, where the globals are to be used
/// pAddList is a comma-list of global specs, like "A,B:(""sub"")",C"
/// pFrom is the database containing the globals
/// The mappings are assumed to not exist, use DeleteGlobalMappings to remove them first
/// pSetCollation is set to force Collation of the mapping to use the new global collation for the pFrom database
/// This is needed for some SLM (Subscript Level Mapping) cases, such as ^OBJ.DSTIME
ClassMethod AddGlobalMappings(pNamespace As %String, pAddList As %String, pFrom As %String, pSetCollation As %Boolean = 0) As %Status [ Internal ]
{
	Set pFrom = ..GetCorrectedDatabase(pFrom)
	New $namespace
	// Run in %SYS
 	Set $namespace="%SYS"
	kill p set p("Database")=pFrom
	If pSetCollation {
		Set tSC = ##Class(Config.Databases).Get(pFrom,.tDBProperties)
		if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		Set tDB=##class(SYS.Database).%OpenId(tDBProperties("Directory"),0,.tSC)
		if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		Set:$IsObject(tDB) p("Collation")=tDB.NewGlobalCollation
	}
	for i=1:1:$l(pAddList,",") {
		set tGlo=$p(pAddList,",",i) if tGlo[":(" set tGlo=$p(tGlo,":(")_"("_$p(tGlo,":(",2,999) // 2008 has glo:(subs), 2009 has glo(subs)
		if '##Class(Config.MapGlobals).Exists(pNamespace,tGlo) {
			set tSC=##Class(Config.MapGlobals).Create(pNamespace,tGlo,.p,,1) // save only
			if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
	}
	Quit $$$OK
}

/// Newer version of AddGlobalMappings.  pAddList is a $List instead of a comma separated list,
/// and we don't remove the ":".  This enables multiple subscripts as well as ranges
ClassMethod AddGlobalMappingsNew(pNamespace As %String, pAddList, pFrom As %String, pSetCollation As %Boolean = 0) As %Status [ Internal ]
{
	Set pFrom = ..GetCorrectedDatabase(pFrom)
	New $namespace
	// Run in %SYS
 	Set $namespace="%SYS"
	kill p set p("Database")=pFrom
	If pSetCollation {
		Set tSC = ##Class(Config.Databases).Get(pFrom,.tDBProperties)
		if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		Set tDB=##class(SYS.Database).%OpenId(tDBProperties("Directory"),0,.tSC)
		if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		Set:$IsObject(tDB) p("Collation")=tDB.NewGlobalCollation
	}
	for i=1:1:$ll(pAddList) {
		set tGlo=$li(pAddList,i)
		if '##Class(Config.MapGlobals).Exists(pNamespace,tGlo) {
			set tSC=##Class(Config.MapGlobals).Create(pNamespace,tGlo,.p,,1) // save only
			if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
	}
	Quit $$$OK
}

/// Remove a list of global mappings
ClassMethod DeleteGlobalMappings(pNamespace As %String, pDeleteList As %String = "") As %Status [ Internal ]
{
	New $namespace
	Set $namespace="%SYS"
	// For each entry in the deletelist, clear it
	for i=1:1:$l(pDeleteList,",") {
		set tGlo=$p(pDeleteList,",",i) if tGlo[":(" set tGlo=$p(tGlo,":(")_"("_$p(tGlo,":(",2,999) // 2008 has glo:(subs), 2009 has glo(subs)
		if ##Class(Config.MapGlobals).Exists(pNamespace,tGlo) {
			set tSC=##Class(Config.MapGlobals).Delete(pNamespace,tGlo) if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
		}
	}
	Quit $$$OK
}

ClassMethod CreateEnsembleMappings(pNamespace) As %Status [ Internal ]
{
	New $namespace
	Set $namespace="%SYS"
	Set:'$D(^%SYS("Ensemble","InstalledNamespace",pNamespace)) ^%SYS("Ensemble","InstalledNamespace",pNamespace)=""
	Quit ##class(%EnsembleMgr).createMappings(pNamespace)
}

ClassMethod DeleteResource(pResource) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		new $namespace
		set $namespace="%SYS"
		set tExists=##class(Security.Resources).Exists(pResource)
		if tExists {
		set tSC=##class(Security.Resources).Delete(pResource)
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

ClassMethod AddUpdateResource(pResource, pDescription, pPublicPermissions = "") As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		new $namespace
		set $namespace="%SYS"
		If '##class(Security.Resources).Exists(pResource) {
			Set tSC=##class(Security.Resources).Create(pResource, pDescription , pPublicPermissions)
		} Else {
			Set tParam("Description")= pDescription
			Set tParam("PublicPermission")= pPublicPermissions
			Set tSC= ##class(Security.Resources).Modify(pResource, .tParam)
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

ClassMethod DeleteRole(pRole) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		IF $E(pRole,1,3)="%HS" Quit  // skip deleting %HS roles - not allowed by system
		new $namespace
		set $namespace="%SYS"
		set tExists=##class(Security.Roles).Exists(pRole)
		if tExists {
		set tSC=##class(Security.Roles).Delete(pRole)
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Adds/updates a System level role with the provides properties. <br />
/// @Argument	pRole						Name of the role. <br />
/// @Argument	pDescription				Description of the role. <br />
/// @Argument	pResources					Comma-separated list of resources granted to the role with
/// the permission level (e.g. "MyResource:RW,MyResource1:RWU"). <br />
/// @Argument	pGrantedRoles				Comma-separated list of additional roles granted when this
/// role is granted to a user (e.g. "GrantedRole1,GrantedRole2"). <br />
ClassMethod AddUpdateRole(pRole As %String, pDescription As %String, pResources As %String, pGrantedRoles As %String = "") As %Status [ Internal ]
{
	Set tSC = $$$OK
	Try {
		New $Namespace
		Set $Namespace = "%SYS"
		If '##class(Security.Roles).Exists(pRole) {
			Set tSC = ##class(Security.Roles).Create(pRole, pDescription , pResources, pGrantedRoles)
		} Else {
			Set tParam("Description") = pDescription
			Set tParam("Resources") = pResources
			Set tParam("GrantedRoles") = pGrantedRoles
			Set tSC = ##class(Security.Roles).Modify(pRole, .tParam)
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Either adds the system level role or updates it in a custom manner based on the provided parameters. <br />
/// @Argument	pRole				Name of the role. <br />
/// @Argument	pCustomList			A $ListBuild list of properties to use, with a flag for each for
/// custom behavior as follows: <br />
/// Flag = 0 means override with the provided value <br />
/// Flag = 1 means append to existing value <br />
/// No flag defaults to 0 <br />
/// If no value is provided, the property will not be populated <br />
/// Format of list: $ListBuild("Description~flag", "Resources~flag", "GrantedRoles~flag") <br />
ClassMethod AddUpdateRoleCustom(pRole As %String, pCustomList As %Library.List)
{
	#define QuitIfError(%sc) If $$$ISERR(%sc) { Quit }
	#define ExtractValue(%var) $Piece(%var, "~", 1)
	#define ExtractFlag(%var) +$Piece(%var, "~", 2)
	Set sc = $$$OK
	Try {
		New $Namespace
		Set $Namespace = "%SYS"
		// Get properties and their flags
		If $ListData(pCustomList, 1, descriptionWithFlag) {
			Set description = $$$ExtractValue(descriptionWithFlag)
			Set descriptionFlag = $$$ExtractFlag(descriptionWithFlag)
		}
		If $ListData(pCustomList, 2, resourcesWithFlag) {
			Set resources = $$$ExtractValue(resourcesWithFlag)
			Set resourcesFlag = $$$ExtractFlag(resourcesWithFlag)
		}
		If $ListData(pCustomList, 3, grantedRolesWithFlag) {
			Set grantedRoles = $$$ExtractValue(grantedRolesWithFlag)
			Set grantedRolesFlag = $$$ExtractFlag(grantedRolesWithFlag)
		}
		// Add/modify role in database
		If '##class(Security.Roles).Exists(pRole) {
			Set sc = ##class(Security.Roles).Create(pRole, .description, .resources, .grantedRoles)
			$$$QuitIfError(sc)
		} Else {
			// Get existing values
			Set tSC = ##class(Security.Roles).Get(pRole, .existingProperties)
			$$$QuitIfError(tSC)
			Set existingDescription = $Get(existingProperties("Description"))
			Set existingResources = $Get(existingProperties("Resources"))
			Set existingGrantedRoles = $Get(existingProperties("GrantedRoles"))
			// Populate properties array
			If $Data(description) {
				If descriptionFlag {
					Set description = existingDescription _ description
				}
				Set properties("Description") = description
			}
			If $Data(resources) {
				If resourcesFlag {
					Set resources = $ListToString( $ListFromString(existingResources) _ $ListFromString(resources) )
				}
				Set properties("Resources") = resources
			}
			If $Data(grantedRoles) {
				If grantedRolesFlag {
					Set grantedRoles = $ListToString( $ListFromString(existingGrantedRoles) _ $ListFromString(grantedRoles) )
				}
				Set properties("GrantedRoles") = grantedRoles
			}
			
			Set sc = ##class(Security.Roles).Modify(pRole, .properties)
			$$$QuitIfError(sc)
		}
	} Catch ex {
		Set sc = ex.AsStatus()
	} 
	Quit sc
}

/// pPropertiesList is a name-value pair list, constructed by $$$NVPairToList(a name-value-pair array)
/// of properties in Security.SSLConfigs
ClassMethod CreateSSLConfig(pConfigName, pPropertiesList) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		new $namespace
		set $namespace="%SYS"
		Do ..ListToNVPair(pPropertiesList,.tProperties)
		If '##class(Security.SSLConfigs).Exists(pConfigName) {
			Set tSC = ##class(Security.SSLConfigs).Create(pConfigName,.tProperties)
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// pForceEnable = 1 to force enabling of user on HC and IFH systems
ClassMethod CreateServiceUser(pForceEnable As %Boolean = 0) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Set tUser = $$$HSServiceUserName,tUserFullName="HealthShare Services (Internal use - not for login)", tSC=$$$OK
		Set tRole = $$$HSServiceRole
		// If %HS_ServiceRole role does not exist, create it.
		Set tSC = ..CreateServiceRole()
		$$$ThrowOnError(tSC)
		new $namespace
		set $namespace="%SYS"
		// If HS_Services user does not exist, create it.  Updated to pass AccountNeverExpires and PasswordNeverExpires properties.
		If '##class(Security.Users).Exists(tUser,.User) {
			Set tEnabled = pForceEnable || ##class(%ZHSLIB.HealthShareMgr).IsHealthShareInstance()
			Set tSC=##Class(Security.Users).Create(tUser,tRole,tUser,tUserFullName,,,,,tEnabled,,,,,,1,1)
			$$$ThrowOnError(tSC)
		}
		Else {
			// if HS_Services already exists, update AccountNeverExpires and PasswordNeverExpires properties.
			If pForceEnable {
				Set User.Enabled = 1
			}
			Set User.AccountNeverExpires=1
			Set User.PasswordNeverExpires=1
			Set tSC=User.%Save() 
			$$$ThrowOnError(tSC)
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Create the %HS_ServiceRole role if it does not exist
ClassMethod CreateServiceRole() As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		new $namespace
		set $namespace="%SYS"
		If '##class(Security.Roles).Exists($$$HSServiceRole) {
			Set tSC = ##class(Security.Roles).Create($$$HSServiceRole, "Role for "_$$$HSServiceUserName)
			$$$ThrowOnError(tSC)
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Used to assign all SQL permissions to a role.
ClassMethod SetupPermissions(pNamespace As %String = {$namespace}, pRole As %String) As %Status [ Internal ]
{
	new $namespace
	if $g(pRole)="" set pRole="%HS_DB_"_pNamespace
	set $namespace=pNamespace
	Set tSC=$SYSTEM.SQL.GrantObjPriv("*","*","TABLE",pRole)
	Set:$$$ISOK(tSC) tSC=$SYSTEM.SQL.GrantObjPriv("*","*","VIEW",pRole)
	quit tSC
}

ClassMethod AddEnsembleSQLPrivileges(pNamespace) As %Status [ Internal ]
{
	Quit ##class(%EnsembleMgr).addEnsembleSQLPrivileges(pNamespace)
}

/// This wraps $System.SQL.GrantObjPriv
/// pType is Table, View, or Stored Procedure
/// pList is a $Listbuild or table, view, or procedure names
ClassMethod SQLGrant(pNamespace, pPrivilege, pType, pList, pRole, pWGrant As %Integer = 0) As %Status [ Internal ]
{
	New $Namespace Set $Namespace=pNamespace
	Quit $System.SQL.GrantObjPriv(pPrivilege,$ListToString(pList),pType,pRole,pWGrant)
}

/// pPortaldir is relative to $system.Util.InstallDirectory()
/// In general, this doesn't update an existing CSP app.  However, it will merge in any additional roles passed into pGrant
ClassMethod CreateCSPApp(pIsUserPortal As %Boolean = 1, pPortal As %String, pNS As %String, pPortalDir As %String, pDescription As %String, pGrant As %String = "", pCookiePath As %String = "", pSuperclass As %String = "", pSessionEventsClass As %String = "", pInbndWebServicesEnabled As %Boolean = 0) As %Status [ Internal ]
{
	If ($G(pPortal)="") || ($G(pNS)="") || ($G(pPortalDir)="") {
		Set msg = "- ERROR when creating Portal application: Application name, namespace and directory must not be null"
		Set tSC = $$$ERROR($$$GeneralError,msg)
		Quit tSC
	}
	Set tSC=$$$OK
	New $Namespace
	Set $Namespace="%SYS"
	Try {
		Set tPortalDirFull=..DirRef(pPortalDir)
	 	If '##class(%File).DirectoryExists(tPortalDirFull) {
			Do ##class(%File).CreateDirectory(tPortalDirFull)
	 	}
 
	 	// Ensure the cookie path is reasonable and ends in a /
	 	Set:$G(pCookiePath)="" pCookiePath = pPortal
	 	Set:$E(pCookiePath,$L(pCookiePath))'="/" pCookiePath = pCookiePath_"/"

		// if the CSP application exists, update only DeepSee-ness; otherwise quit.
	 	If ##class(Security.Applications).Exists(pPortal, .tApp, .tSC) {
			If pIsUserPortal {
				//Enable Deepsee
				Set tDSApp=pPortal Set:$E(tDSApp,$L(tDSApp))'="/" tDSApp=tDSApp_"/"
				do EnableDeepSee^%SYS.cspServer(tDSApp)
				//also enable hslib, to prevent users from getting stuck in "forbidden" without being able to easily switch to the registry
				do EnableDeepSee^%SYS.cspServer("/csp/hslib/")
			}
			Set tSC= ..MergeCSPRoles(pPortal,pGrant) Quit
	 	}
		Set tApp = ##class(Security.Applications).%New()
		Set CSPAppSec = $$$AutheCache // Cache password
		If pIsUserPortal Set CSPAppSec=CSPAppSec+ $$$AutheDelegated // users can be delegated
		Set tApp.Name = pPortal
		Set tApp.AutheEnabled = CSPAppSec
		Set tApp.Description = pDescription
		Set tApp.AutoCompile = 0
		Set tApp.Timeout= 900
		Set tApp.Path = tPortalDirFull
		Set tApp.SuperClass=pSuperclass
		Set tApp.InbndWebServicesEnabled = pInbndWebServicesEnabled
		// Add a matching role for HS_Services if the application is web services enabled and this is a HealthShare instance
		If (pInbndWebServicesEnabled) && ##class(%ZHSLIB.HealthShareMgr).IsHealthShareInstance() {
			Set tSC = tApp.MatchRoles.Insert($$$HSServiceRole_":%All")
			$$$ThrowOnError(tSC)
		}
		If pGrant'="" {
			Set tGrant=""
			For i = 1:1:$L(pGrant,",") {
				Set r = $P(pGrant,",",i)
				Set:r'="" tGrant=tGrant_":"_r
			}
			//tGrant must be of format :grant1:grant2 etc
			Do:tGrant'="" tApp.MatchRoles.Insert(tGrant)
		 }
		Set tApp.CSRFToken = pIsUserPortal
		Set tApp.CookiePath = pCookiePath
		Set tApp.NameSpace = pNS
		Set tApp.CSPZENEnabled = pIsUserPortal
		Set tApp.DeepSeeEnabled = pIsUserPortal
		Set ^%SYS("Ensemble","CSPApp",$zcvt(pNS,"U"),"GroupById",pPortal) = ""
		Set tApp.EventClass = pSessionEventsClass
		Set tApp.GroupById = $$$IscMgtPortalId
		Set tApp.ServeFiles = 2 // Always and Cached
		Set tApp.UseCookies = 2 // Set UseCookies to Always
		
		// Save Portal's CSP application
		Set tSC = tApp.%Save()
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

ClassMethod DeleteCSPApp(pPortal As %String, pPurgeFiles As %String) As %Status [ Internal ]
{
	Set tSC= ##class(%Library.EnsembleMgr).deletePortal(pPortal,pPurgeFiles,1)
	Quit tSC
}

/// Only supports application roles, not match roles
ClassMethod MergeCSPRoles(pPortal As %String, pGrant As %String) As %Status [ Internal ]
{
	Set tSC=$$$OK
	New $Namespace
	Set $Namespace="%SYS"
	Try {
		Do ##class(Security.Applications).Exists(pPortal, .tApp, .tSC) Quit:$$$ISERR(tSC)  //will return an error if app doesn't exist
		Set tGot=0
		For tI=1:1:tApp.MatchRoles.Count() {
			Set tMatch=tApp.MatchRoles.GetAt(tI)
			If $P(tMatch,":")="",tMatch'="" {
				Set tGot=1
				For i = 1:1:$L(pGrant,",") {
					Set r = $P(pGrant,",",i)
					Continue:r=""
					If tMatch_":"'[(":"_r_":") Set tMatch=tMatch_":"_r
				}
				Do tApp.MatchRoles.SetAt(tMatch,tI)
			}
		}
		If 'tGot {
			Set tGrant=""
			For i = 1:1:$L(pGrant,",") {
				Set r = $P(pGrant,",",i)
				Set:r'="" tGrant=tGrant_":"_r
			}
			//tGrant must be of format :grant1:grant2 etc
			Do:tGrant'="" tApp.MatchRoles.Insert(tGrant)
		 }
		 Set tSC=tApp.%Save()
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Enables CSRF protection for all non-REST CSP applications
ClassMethod EnableCSRFProtection() As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		New $namespace
		Set $namespace="%SYS"
		// Presence of a Dispatch Class indicates the app is REST based
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,
			"update Security.Applications set CSRFToken = 1 where CSPZENEnabled = 1 and DispatchClass is null")
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Sets a session events class for all web applications that meet all of the following criteria:
/// <ol>
/// <li>The web application has no existing session events class</li>
/// <li>The <class>HS.Util.Installer.Config</class> item for the application's namespace
/// 		specifies a default CSP Session Events class</li>
/// <li>The web application has delegated authentication enabled</li>
/// </ol>
ClassMethod SetSessionEventsForDelegatedCSPApplications() As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		New $namespace
		Set $namespace = "HSLIB"
		
		// Identify installed HealthShare and Health Connect namespaces
		// Build up a map of the default CSP Session Events handler for each namespace
		Set tNamespaceHandlerMap = ##class(%Library.ArrayOfDataTypes).%New()
		Set tNamespaceRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT Name FROM HS_Util_Installer.ConfigItem")
		If (tNamespaceRS.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tNamespaceRS.%SQLCODE, tNamespaceRS.%Message)
		}
		While tNamespaceRS.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tNamespace = tNamespaceRS.%Get("Name")
			
			// Don't add the namespace to the map if an event handler isn't specified
			Set tCSPSessionEventsClass = ##class(HS.Util.Installer.ConfigItem).GetDefaultCSPSessionEventsClassForNamespace(tNamespace)
			If (tCSPSessionEventsClass '= "") {
				$$$ThrowOnError(tNamespaceHandlerMap.SetAt(tCSPSessionEventsClass,tNamespace))
			}
		}
		If (tNamespaceRS.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tNamespaceRS.%SQLCODE, tNamespaceRS.%Message)
		}
		
		// Add handling for namespaces that don't have a ConfigItem defined
		Set tDefaultCSPSessionEventsClass = ##class(HS.Util.Installer.ConfigItem).GetDefaultCSPSessionEventsClass()
		
		Set tIsHealthShareInstance = ##class(%ZHSLIB.HealthShareMgr).IsHealthShareInstance()
		If (tIsHealthShareInstance) && ##class(%Dictionary.CompiledClass).%ExistsId("HS.Util.Installer.HealthShareType") {
			Set tDefaultCSPSessionEventsClass = ##class(HS.Util.Installer.HealthShareType).GetDefaultCSPSessionEventsClass()
		}
		
		If (tDefaultCSPSessionEventsClass '= "") {
			#dim tNonAppNamespaces As %Library.DynamicArray
			Set tNonAppNamespaces = [ "HSSYS", "HSLIB" ]
			
			// Add other HealthShare product namespaces if HealthShare is installed
			If (tIsHealthShareInstance) {
				Set tOtherHSLibraryNamespaces = ##class(%ZHSLIB.HealthShareMgr).GetDatabaseList()
				Set tOtherHSPointer = 0
				While $ListNext(tOtherHSLibraryNamespaces, tOtherHSPointer, tOtherHSNamespace) {
					Do tNonAppNamespaces.%Push(tOtherHSNamespace)
				}
			}
			
			Set tNonAppIterator = tNonAppNamespaces.%GetIterator()
			While tNonAppIterator.%GetNext( , .tNonAppNamespace) {
				If ('tNamespaceHandlerMap.IsDefined(tNonAppNamespace)) && ##class(%SYS.Namespace).Exists(tNonAppNamespace) {
					$$$ThrowOnError(tNamespaceHandlerMap.SetAt(tDefaultCSPSessionEventsClass,tNonAppNamespace))
				}
			}
		}
		
		Set $namespace="%SYS"
		#dim tResultSet As %SQL.StatementResult
		Set tStatement = ##class(%SQL.Statement).%New()
		// The class query runs in display mode by default, but ensure that we force that
		Set tStatement.%SelectMode = 2
		$$$ThrowOnError(tStatement.%PrepareClassQuery("Security.Applications", "Detail"))
		// "*" means to get applications matching any names. 2 indicates that only CSP applications should be returned.
		Set tAppResultSet = tStatement.%Execute("*", 2)
		If (tAppResultSet.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tAppResultSet.%SQLCODE, tAppResultSet.%Message)
		}
		// Iterate result set modifying necessary web applications
		While tAppResultSet.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			// Check if EventClass exists. Do not override
			If (tAppResultSet.%Get("EventClass") '= "") {
				Continue
			}
			Set tNamespace = tAppResultSet.%Get("NameSpace")
			// Check if this namespace is defined in tNamespaceHandlerMap
			If 'tNamespaceHandlerMap.IsDefined(tNamespace) {
				Continue
			}
			// Check if delegated authentication
			// Note that the AutheEnabled column returns values in display value,
			// so we need to convert it to a logical value
			Set tAutheEnabledDisplayValue = tAppResultSet.%Get("AutheEnabled")
			Set tAutheEnabledLogical      = ##class(Security.Applications).AutheEnabledDisplayToLogical(tAutheEnabledDisplayValue)
			// Check if the current tAutheEnabledLogical value includes the delegated bits
			If '($zboolean(tAutheEnabledLogical,$$$AutheDelegated,1)) {
				Continue
			}
			
			Set tApplication = tAppResultSet.%Get("Name")
			// Modify session events class
			Kill tProperties
			Set tProperties("EventClass") = tNamespaceHandlerMap.GetAt(tNamespace)
			
			$$$ThrowOnError(##class(Security.Applications).Modify(tApplication, .tProperties))
		}
		$$$ThrowOnError(tSC)
	} Catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Remove the ENSDEMO HS.Util.Installer.ConfigItem object if it exists
ClassMethod RemoveENSDEMOConfigItem() As %Status [ Internal ]
{
	Set sc = $$$OK
	If ##class(HS.Util.Installer.ConfigItem).%ExistsId("ENSDEMO") {
		Set sc = ##class(HS.Util.Installer.ConfigItem).%DeleteId("ENSDEMO")
	}
	Return sc
}

/// pPropertiesList is a name-value pair list, constructed by $$$NVPairToList(a name-value-pair array)
/// of properties in the portal
/// If pRelativePath is true, then if Path is a name in the property list,
/// it will be treated as relative to $system.Util.InstallDirectory()
/// The pMode parameter can be "u" to perform a Modify, "c" to Create, or "n" to delete
/// an previous one and then create.
ClassMethod UpdateCSPApp(pPortal, pPropertiesList, pRelativePath As %Boolean = 1, pMode As %String = "u") As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Do ..ListToNVPair(pPropertiesList,.tProperties)
		If pRelativePath,$D(tProperties("Path")) {
			Set tProperties("Path")=..DirRef(tProperties("Path"),1)
		}
		
		new $namespace
		set $namespace="%SYS"
		Set tAppObj = ""
		Set tExists = ##class(Security.Applications).Exists(pPortal,.tAppObj, .tSC)
		if tExists {
			// If "new" mode, then delete any existing App
			if pMode="n" {
				Set tSC = ##class(Security.Applications).Delete(pPortal)
				if $$$ISERR(tSC) quit
			}
		}
		// If CSP app is ZEN enabled (and CSRF token not already set) then provide CSRF protection. If it is also REST, then disable CSRF protection
		Set tIsCSPZenEnabled = ($Get(tProperties("CSPZENEnabled")) = 1) || ($IsObject(tAppObj) && +tAppObj.CSPZENEnabled)
		Set tHasCSRFTokenSet = $Data(tProperties("CSRFToken"))#2
		If 'tHasCSRFTokenSet && tIsCSPZenEnabled {
			Set tHasDispatchClass = ($Get(tProperties("DispatchClass")) '= "") || ($IsObject(tAppObj) && (tAppObj.DispatchClass '= ""))
			If 'tHasDispatchClass {
				Set tProperties("CSRFToken") = 1
			} Else {
				Set tProperties("CSRFToken") = 0
			}
		}
		
		if pMode="u" {
			Set tSC = ##class(Security.Applications).Modify(pPortal,.tProperties)
		} else {
			Set tSC = ##class(Security.Applications).Create(pPortal,.tProperties)
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

ClassMethod AddCSPXSLTapplication() As %Status [ Internal ]
{
	Set tSC=$$$OK
	new $namespace
	Set tSLASH = $S($$$isUNIX:"/",1:"\")
	try {
		set $namespace="HSLIB"
		set tCSPSessionEventsClass = ""
		if ##class(%ZHSLIB.HealthShareMgr).IsHealthShareInstance() && ##class(%Dictionary.CompiledClass).%ExistsId("HS.Util.Installer.HealthShareType") {
			set tCSPSessionEventsClass = ##class(HS.Util.Installer.HealthShareType).GetDefaultCSPSessionEventsClass()
		}
		set InstallDir=$system.Util.InstallDirectory()
		Set tXSLTSourceDir=InstallDir_"csp"_tSLASH_"xslt"_tSLASH
		If $D(^Sources)#11 Set ^["%SYS"]SYS("Security","CSP","AllowPrefix","/csp/healthshare/hsregistry/","%UnitTest.")=1
		set $namespace="%SYS"
		set tExists=##class(Security.Applications).Exists("/csp/xslt")
		// Note: This does not update an existing application !
		If 'tExists {
			Set tSC = ##class(%EnsembleMgr).createPortalApp("/csp/xslt","HSLIB",tXSLTSourceDir,"xslt files","",1,"",$g(tRoles),"/csp/xslt",32,0) 
			Quit:$$$ISERR(tSC)
			If (tCSPSessionEventsClass '= "") {
				Set tCSPProperties("EventClass") = tCSPSessionEventsClass
				Set tSC = ##class(Security.Applications).Modify("/csp/xslt",.tCSPProperties)
				Quit:$$$ISERR(tSC)
			}
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

ClassMethod AllowPrefix(pNamespace, pPrefix) As %Status [ Internal ]
{
	Set tSC=$$$OK
	new $namespace
	try {
		Set ^["%SYS"]SYS("Security","CSP","AllowPrefix","/csp/healthshare/"_$zcvt(pNamespace,"l")_"/",pPrefix)=1
	} catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// pGrantType := "AllowClass" | "AllowPrefix"
/// pCSPApplication := csp application with leading and trailing "/"
/// pAccessItem := classname | prefix
/// pAccessEnabled := 1 | 0
ClassMethod UpdateCSPPercentAccess(pGrantType As %String, pCSPApplication As %String, pAccessItem As %String, pAccessEnabled As %Boolean) As %Status
{
	Set tSC=$$$OK
	try {
		Set pGrantType=$ZCVT(pGrantType,"l")
		If pGrantType="allowclass" {
			Set ^["%SYS"]SYS("Security","CSP","AllowClass",pCSPApplication,pAccessItem)=pAccessEnabled
		} ElseIf pGrantType="allowprefix" {
			Set ^["%SYS"]SYS("Security","CSP","AllowPrefix",pCSPApplication,pAccessItem)=pAccessEnabled
		} Else {
			Set tSC = $$$ERROR($$$GeneralError,"pGrantType must be AllowClass or AllowPrefix")
		}
	} catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// pSyncSlaveCheck: null - no check.  "Slave" - run only on slave.
///  "Hub" (or anything else) - run only on non-slave instance, meaning
///  we're in a pure foundation namespace, or, otherwise, there's a hub
ClassMethod ScheduleTask(pTaskClass, pNamespace, pSyncSlaveCheck = "") As %Status [ Internal ]
{
	New $Namespace
	Set $Namespace=pNamespace
	If pSyncSlaveCheck'="" {
		Set tIsSyncSlave=##class(HS.Sync.Utils).IsSyncSlave()
		If pSyncSlaveCheck="Slave" {Quit:'tIsSyncSlave $$$OK}
		Else  {Quit:tIsSyncSlave $$$OK}
	}
	Quit $ClassMethod(pTaskClass,"Schedule",pNamespace)
}

/// Used by the data volume reports, which take an additional argument
ClassMethod ScheduleTaskDaily(pTaskClass, pNamespace, pRunDaily As %Boolean = 1) As %Status [ Internal ]
{
	New $Namespace
	Set $Namespace=pNamespace
	Quit $ClassMethod(pTaskClass,"Schedule",pNamespace,pRunDaily)
}

/// Delete all Tasks for the namespace
ClassMethod DeleteTasks(pNamespace = {$namespace}) As %Status [ Internal ]
{
	&sql(Delete from %SYS.Task where Namespace=:pNamespace AND TaskClass !='HS.Util.Mirror.Task')
	Quit $$$OK
}

ClassMethod DeleteOneTask(pTaskClass, pNamespace = {$namespace}) As %Status [ Internal ]
{
	&sql(Delete from %SYS.Task where Namespace=:pNamespace AND TaskClass=:pTaskClass)
	Quit $$$OK
}

/// pDirectory is relative to $system.Util.InstallDirectory(), unless pRelative passed in =0
ClassMethod CreateDirectoryChain(pDirectory, pRelative As %Boolean = 1) As %Status [ Internal ]
{
	Set tOK=##class(%File).CreateDirectoryChain(..DirRef(pDirectory,pRelative))
	If 'tOK Quit $$$ERROR($$$GeneralError,"Unable to create directory "_pDirectory)
	Quit $$$OK
}

/// pDirectory is relative to $system.Util.InstallDirectory(), unless pRelative passed in =0
ClassMethod RemoveDirectory(pDirectory, pRelative As %Boolean = 1) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Set tOK=##class(%File).RemoveDirectoryTree(..DirRef(pDirectory,pRelative))
		If 'tOK Set tSC=%objlasterror
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// pSrc and pTarget are relative to $system.Util.InstallDirectory(), unless pRelative passed in =0
ClassMethod CopyDirectory(pSrc As %String, pTarget As %String, pRelative As %Boolean = 1) As %Status [ Internal ]
{
	set %objlasterror = $$$OK,tSC=$$$OK
	set tOK=##class(%File).CopyDir(..DirRef(pSrc,pRelative),..DirRef(pTarget,pRelative),1)
	if 'tOK {
		if $$$ISERR(%objlasterror) {set tSC=%objlasterror}
		else {set tSC=$$$ERROR($$$FileCanNotCopy,..DirRef(pSrc,pRelative),..DirRef(pTarget,pRelative))}
	}
	quit tSC
}

/// pSrcDir and pTargetDir are relative to $system.Util.InstallDirectory(), unless pRelative passed in =0
ClassMethod CopyFileToFile(pSrcDir As %String, pSrcFile As %String, pTargetDir As %String, pTargetFile As %String, pRelative As %Boolean = 1) As %Status [ Internal ]
{
	set tSC=$$$OK
	Set tFrom=..FileRef(pSrcDir,pSrcFile,pRelative)
	Set tThru=..FileRef(pTargetDir,pTargetFile,pRelative)
	set tOK=$zu(140,11,tFrom,tThru) // 0 = success
	if tOK'=0 set tSC=$$$ERROR($$$FileCanNotCopy,tFrom,tThru)
	quit tSC
}

/// pDirectory is relative to $system.Util.InstallDirectory(), unless pRelative passed in =0
ClassMethod CopyStringToFile(pString, pDirectory, pFileName, pAppend As %Boolean = 0, pRelative As %Boolean = 1) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Set tFile=..FileRef(pDirectory,pFileName,pRelative)
		If 'pAppend,##class(%File).Exists(tFile) {
			Set tOK=##class(%File).Delete(tFile)
			If 'tOK Set tSC=$$$ERROR($$$FileCanNotDelete,tFile) Quit
		}
		Set tFileObj=##class(%File).%New(tFile)
		Do tFileObj.Open("WSA",2)
		If 'tFileObj.IsOpen Set tSC=$$$ERROR($$$FileCanNotOpen,tFile) Quit
		If pAppend Do tFileObj.MoveToEnd()
		Do tFileObj.Write(pString),tFileObj.Close()
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// pDirectory is relative to $system.Util.InstallDirectory(), unless pRelative passed in =0.
/// Will create if needed.
/// Copies entire stream (we're assuming a max stream length of 999999999)
ClassMethod CopyStreamToFile(pStream, pDirectory, pFileName, pRelative As %Boolean = 1) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		Set tSC=..CreateDirectoryChain(pDirectory) Quit:$$$ISERR(tSC)
		Set tFile=..FileRef(pDirectory,pFileName,pRelative)
		If ##class(%File).Exists(tFile) {
			Set tOK=##class(%File).Delete(tFile)
			If 'tOK Set tSC=$$$ERROR($$$FileCanNotDelete,tFile) Quit
		}
		Set tFileObj=##class(%File).%New(tFile)
		Do tFileObj.Open("WSA",2)
		If 'tFileObj.IsOpen Set tSC=$$$ERROR($$$FileCanNotOpen,tFile) Quit
		Do pStream.Rewind()
		Do tFileObj.Write(pStream.Read(999999999)),tFileObj.Close()
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

ClassMethod ActivateConfiguration(pNS = {$namespace}) As %Status [ Internal ]
{
	Set tSC=$$$OK
	New $Namespace Set $Namespace="%SYS"
	Try {
		set tSC=##Class(Config.CPF).Write() Quit:$$$ISERR(tSC)
		set tSC=##Class(Config.Map).MoveToActive() Quit:$$$ISERR(tSC)
		set tSC=##Class(Config.Namespaces).Load(pNS) Quit:$$$ISERR(tSC)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// The HS.UI.Custom.* package fails to compile sometimes upon upgrade from
/// a CE based HS instance to an IRIS based HS instance. Hence, they should
/// be recompiled after all other classes have been compiled, as an upgrade step.
ClassMethod RecompileUICustomPackage() As %Status [ Internal ]
{
	New $Namespace
	Set $Namespace = "HSLIB"
	Return $System.OBJ.CompilePackage("HS.UI.Custom", "ck")
}

/// Internal Utility method
ClassMethod FileRef(pRelativeDir, pFile, pRelative As %Boolean = 1) As %String [ Internal ]
{
	Quit ..DirRef(pRelativeDir, pRelative)_pFile
}

/// Internal Utility method
/// In almost all uses, pRelative will be 1
/// If pRelative=0, then we expect file to be an absolute reference
ClassMethod DirRef(pRelativeFile, pRelative As %Boolean = 1) As %String [ Internal ]
{
	If pRelative {
		IF $E(pRelativeFile)="/"||($E(pRelativeFile)="\") Set pRelativeFile=$E(pRelativeFile,2,999)
		Set pRelativeFile=$system.Util.InstallDirectory()_pRelativeFile
	}
	Quit ##class(%File).NormalizeDirectory(pRelativeFile)
}

/// Utility API Method
/// Input a name-value-pair array.  Outputs it as a $List of $List-pairs
ClassMethod NVPairToList(pNVPairArray) As %List [ Internal ]
{
	Set tList="",tName=""
	For {
		Set tName=$O(pNVPairArray(tName),1,tValue) Quit:tName=""
		Set tPair=$LB(tName,tValue)
		Set tList=tList_$LB(tPair)
	}
	Quit tList
}

/// Internal Utility method, Inverse of NVPairToList
/// Input a %List of $List-pairs, and it outputs this as a name-value-pair array
ClassMethod ListToNVPair(pList, Output pArray) [ Internal ]
{
	Kill pArray
	For tI=1:1:$LL(pList) {
		Set tPair=$LG(pList,tI)
		Set pArray($LG(tPair))=$LG(tPair,2)
	}
}

/// Update the resource for the database for a specified namespace.
ClassMethod UpdateDatabaseResource(pNamespace As %String, pResource As %String) As %Status [ Internal ]
{
	Set tSC=$$$OK
	Try {
		New $namespace
		Set $Namespace="%SYS"
		set dir = ##class(Config.Databases).GetDirectory($TR(pNamespace,"%-_","PDU"))
		set tSC = ##class(SYS.Database).ModifyDatabase(dir,,pResource)
		//w t
		$$$ThrowOnError(tSC)
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

/// Update HS_Services to replace %All with %HS_ServiceRole and update any /services CSP applications 
/// in the current namespace or HSSYS to have a matching role to give HS_Services %All in those applications only
ClassMethod SetMatchingRoleForServicesCSPApplications() As %Status [ Internal ]
{
	Set sc = $$$OK
	Try {
		// If %HS_ServiceRole role does not exist, create it.
		Set sc = ..CreateServiceRole()
		$$$ThrowOnError(sc)
		
		set currentNS = $namespace
		New $namespace
		Set $namespace="%SYS"
		#dim appResultSet As %SQL.StatementResult
		Set statement = ##class(%SQL.Statement).%New()
		Set statement.%SelectMode = 2
		$$$ThrowOnError(statement.%PrepareClassQuery("Security.Applications", "NamespaceList"))
		// Get all applications for the current namespace and HSSYS
		Set appResultSet = statement.%Execute(currentNS_",HSSYS")
		If (appResultSet.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(appResultSet.%SQLCODE, appResultSet.%Message)
		}
		
		// Iterate result set adding new match role for web services enabled applications
		While appResultSet.%Next(.sc) {
			$$$ThrowOnError(sc)
			
			Set matchRole = $$$HSServiceRole_":%All"
			If ##class(Security.Applications).Exists(appResultSet.%Get("Name"), .application, .sc) {
				$$$ThrowOnError(sc)
				
				// Skip if the application is not web services enabled, or if the match role already exists
				If ('application.InbndWebServicesEnabled) || (application.MatchRoles.Find(matchRole)) {
					Continue
				}
				Set sc = application.MatchRoles.Insert(matchRole)
				$$$ThrowOnError(sc)
				Set sc = application.%Save()
				$$$ThrowOnError(sc)
			}
		}
		$$$ThrowOnError(sc)
		
		// Add %HS_ServiceRole to HS_Services user
		Set sc = ##class(Security.Users).AddRoles($$$HSServiceUserName, $$$HSServiceRole)
		$$$ThrowOnError(sc)
		// Remove %All from HS_Services user
		If ##class(Security.Users).Exists($$$HSServiceUserName,.userObj) {
			Set index = userObj.Roles.Find("%All")
			If index {
				Set value = userObj.Roles.RemoveAt(index)
				If value="" {
					$$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to remove %All role from "_$$$HSServiceUserName))
				}
			}
			Set sc = userObj.%Save()
			$$$ThrowOnError(sc)
		}
	} 
	Catch ex {
		Set sc = ex.AsStatus()
	}
	
	Quit sc
}

/// Update HealthShare tasks in the current namespace or HSSYS to run as _Ensemble instead of HS_Services or _SYSTEM
ClassMethod UpdateTasksUsername() As %Status [ Internal ]
{
	Set sc = $$$OK
	Try {
		set currentNS = $namespace
		New $namespace
		Set $namespace = "HSSYS"
		
		// Change the user to _Ensemble for HS tasks in the current namespace or HSSYS
		#dim result As %SQL.StatementResult
		Set statement = ##class(%SQL.Statement).%New()
		Set statement.%SelectMode = 2
		Set query = "UPDATE %SYS.Task SET RunAsUser ='"_$$$HSTaskUserName_"' WHERE ID > 999 AND Type = 'User' AND RunAsUser IN ('HS_Services','_SYSTEM') AND Namespace IN ('"_currentNS_"','"_"HSSYS"_"')"
		$$$ThrowOnError(statement.%Prepare(query))
		Set result = statement.%Execute()
		If (result.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE, result.%Message)
		}	
	} 
	Catch ex {
		Set sc = ex.AsStatus()
	}
	
	Quit sc
}

}
