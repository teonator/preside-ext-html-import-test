component extends="preside.system.base.AdminHandler" {

	property name="htmlImportService" inject="HTMLImportService";

	public function preHandler( event, rc, prc ) {
		super.preHandler( argumentCollection = arguments );
	}

	public void function index( event, rc, prc, args={} ) {
		setNextEvent( url=event.buildAdminLink( linkTo="htmlImport.import" ) );
		return;
	}

	public void function import( event, rc, prc, args={} ) {
		args.formName   = "htmlImport.import";
		args.formId     = Replace( args.formName, ".", "-", "all" );
		args.formAction = event.buildAdminLink( linkTo="htmlImport.importAction" );
		args.formHtml   = renderForm(
			  formName         = args.formName
			, savedData        = rc.savedData        ?: {}
			, validationResult = rc.validationResult ?: ""
			, context          = "admin"
		);

		prc.pageTitle = translateResource( uri="HTMLImport:title" );
		prc.pageIcon  = translateResource( uri="HTMLImport:iconClass" );

		event.addAdminBreadCrumb(
			  title = prc.pageTitle
			, link  = ""
		);

		event.setView( view="admin/htmlImport/import", args=args );
	}

	public void function importAction( event, rc, prc, args={} ) {
		var validationResult = validateForms();
		var formData         = event.getCollectionForForm();

		if ( !validationResult.validated() ) {
			var persistStruct = event.getCollectionWithoutSystemVars();

			persistStruct.validationResult = validationResult;

			setNextEvent(
				  url           = event.buildAdminLink( linkTo="htmlImport.import" )
				, persistStruct = persistStruct
			);
		}

		var taskId = createTask(
			  event             = "admin.HtmlImport.importInBackgroundThread"
			, runNow            = true
			// , discardOnComplete = true
			, adminOwner        = event.getAdminUserId()
			, title             = "HTMLImport:title"
			// , resultUrl         = event.buildAdminLink( linkTo="htmlImport.import" )
			, returnUrl         = event.buildAdminLink( linkTo="htmlImport.import" )
			, args              = {
				  userId                  = event.getAdminUserId()
				, parentPage              = formData.parent_page              ?: ""
				, zipFile                 = formData.zip_file                 ?: {}
				, pageHeading             = formData.page_heading             ?: ""
				, childPagesHeading       = formData.child_pages_heading      ?: ""
				, contentSectionsHeading  = formData.content_sections_heading ?: ""
				, mainContentEditDisabled = isTrue( formData.main_content_edit_disabled ?: "" )
				, childPagesEnabled       = isTrue( formData.child_pages_enabled        ?: "" )
				, contentSectionsEnabled  = isTrue( formData.content_sections_enabled   ?: "" )
			  }
		);

		setNextEvent( url=event.buildAdminLink(
			  linkTo      = "adhoctaskmanager.progress"
			, queryString = "taskId=" & taskId
		) );
	}

	private boolean function importInBackgroundThread( event, rc, prc, args={}, logger, progress ) {
		arguments.logger?.info( "Importing HTML..." );

		htmlImportService.importFromZipFile( argumentCollection=args, logger=arguments.logger, progress=arguments.progress );

		return true;
	}

}