component extends="preside.system.base.AdminHandler" {

	property name="sitetreeService"   inject="SitetreeService";
	property name="htmlImportService" inject="HTMLImportService";

	public function preHandler( event, rc, prc ) {
		super.preHandler( argumentCollection = arguments );
	}

	public void function index( event, rc, prc, args={} ) {
		setNextEvent( url=event.buildAdminLink( linkTo="htmlImport.import" ) );
		return;
	}

	public void function import( event, rc, prc, args={} ) {
		var pageId = rc.page ?: "";

		var savedData = rc.savedData ?: {
			page = pageId
		};

		args.formName       = "htmlImport.import";
		args.formId         = Replace( args.formName, ".", "-", "all" );
		args.formAction     = event.buildAdminLink( linkTo="htmlImport.importAction" );
		args.formCancelLink = event.buildAdminLink( linkTo="SiteTree.editPage", querystring="id=#pageId#" );
		args.formHtml       = renderForm(
			  formName         = args.formName
			, savedData        = savedData
			, validationResult = rc.validationResult ?: ""
			, context          = "admin"
		);

		prc.pageTitle = translateResource( uri="HTMLImport:title"     );
		prc.pageIcon  = translateResource( uri="HTMLImport:iconClass" );

		var ancestors = sitetreeService.getAncestors( id=pageId, selectFields=[ "id", "title" ] );

		for( var ancestor in ancestors ) {
			event.addAdminBreadCrumb(
				  title = ancestor.title
				, link  = event.buildAdminLink( linkTo="sitetree.editpage", queryString="id=#ancestor.id#" )
			);
		}

		var page = sitetreeService.getPage( id=pageId, selectFields=[ "id", "title" ] );

		event.addAdminBreadCrumb(
			  title = page.title ?: ""
			, link  = event.buildAdminLink( linkTo="sitetree.editpage", queryString="id=#pageId#"  )
		);

		event.addAdminBreadCrumb(
			  title = prc.pageTitle
			, link  = ""
		);

		event.setView( view="admin/htmlImport/import", args=args );
	}

	public void function importAction( event, rc, prc, args={} ) {
		var validationResult = validateForms();
		var formData         = event.getCollectionForForm();
		var pageId           = formData.page ?: "";

		if ( !validationResult.validated() ) {
			var persistStruct = event.getCollectionWithoutSystemVars();

			persistStruct.validationResult = validationResult;

			setNextEvent(
				  url           = event.buildAdminLink( linkTo="HTMLImport.import", queryString="page=#pageId#" )
				, persistStruct = persistStruct
			);
		}

		var taskId = createTask(
			  event      = "admin.HtmlImport.importInBackgroundThread"
			, runNow     = true
			, adminOwner = event.getAdminUserId()
			, title      = "HTMLImport:title"
			, returnUrl  = event.buildAdminLink( linkTo="HTMLImport.import", queryString="page=#pageId#" )
			, args       = {
				  userId                  = event.getAdminUserId()
				, page                    = pageId
				, zipFile                 = formData.zip_file            ?: {}
				, pageHeading             = formData.page_heading        ?: ""
				, childPagesHeading       = formData.child_pages_heading ?: ""
				, childPagesType          = formData.child_pages_type    ?: ""
				, mainContentEditDisabled = isTrue( formData.main_content_edit_disabled ?: "" )
				, childPagesEnabled       = isTrue( formData.child_pages_enabled        ?: "" )
			  }
		);

		setNextEvent( url=event.buildAdminLink(
			  linkTo      = "adhoctaskmanager.progress"
			, queryString = "taskId=" & taskId
		) );
	}

	private boolean function importInBackgroundThread( event, rc, prc, args={}, logger, progress ) {
		htmlImportService.importFromZipFile( argumentCollection=args, logger=arguments.logger, progress=arguments.progress );

		return true;
	}

}