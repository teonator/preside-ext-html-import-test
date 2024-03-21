/**
 * @presideService true
 * @singleton      true
 */
component {

	property name="siteTreeService"              inject="SiteTreeService";
	property name="assetManagerService"          inject="AssetManagerService";
	property name="dynamicFindAndReplaceService" inject="DynamicFindAndReplaceService";

	variables._lib   = [];
	variables._jsoup = "";

	public any function init() {
		variables._jsoup = _new( "org.jsoup.Jsoup" );

		return this;
	}

	public string function importFromZipFile(
		  required struct  zipFile
		,          string  page                    = ""
		,          boolean mainContentEditDisabled = false
		,          string  pageHeading             = "h1"
		,          boolean childPagesEnabled       = false
		,          string  childPagesHeading       = "h2"
		,          string  childPagesType          = "standard_page"
		,          any     logger
		,          any     progress
	) {
		var parentPageId = arguments.page;
		var totalPages = 0;

		arguments.logger?.info( "Importing HTML from ZIP..." );

		try {
			if ( !$helpers.isEmptyString( arguments.zipFile.path ?: "" ) ) {
				arguments.logger?.info( "Unpacking ZIP..." );

				var htmlFileDir = _unpackZipFile( zipFilePath=arguments.zipFile.path );
				var htmlContent = _getHtmlContent( htmlFileDir=htmlFileDir );

				if ( !$helpers.isEmptyString( htmlContent ) ) {
					arguments.logger?.info( "Parsing HTML..." );

					var html     = variables._jsoup.parse( htmlContent );
					var elements = html.body().children();

					var pages       = [];
					var pageTitle   = "";
					var pageContent = "";
					var pageChild   = false;

					var pagesHeading = [];
					if ( !$helpers.isEmptyString( arguments.pageHeading ) ) {
						ArrayAppend( pagesHeading, arguments.pageHeading );
					}

					if ( arguments.childPagesEnabled ) {
						ArrayAppend( pagesHeading, arguments.childPagesHeading );
					}

					var tagName = "";
					var tagText = "";

					for ( var element in elements ) {
						var tagName = element.tagName();
						var tagText = element.text();

						if ( ArrayFindNoCase( pagesHeading, tagName ) && !$helpers.isEmptyString( tagText ) ) {
							if ( !$helpers.isEmptyString( pageTitle ) || !$helpers.isEmptyString( pageContent ) ) {
								ArrayAppend( pages, { title=pageTitle, content=pageContent, child=pageChild } );
							}

							pageTitle   = tagText;
							pageContent = "";
							pageChild   = arguments.childPagesHeading == tagName;
						} else {
							pageContent &= element.toString();
						}
					}

					if ( !$helpers.isEmptyString( pageTitle ) || !$helpers.isEmptyString( pageContent ) ) {
						ArrayAppend( pages, { title=pageTitle, content=pageContent, child=pageChild } );
					}

					totalPages = _processPages( argumentCollection=arguments, pages=pages, htmlFileDir=htmlFileDir, parentPageId=parentPageId );
				}
			}
		} catch( any e ) {
			rethrow;
		} finally {
			try {
				DirectoryDelete( zipDir, true );
			} catch( any e ){}
		}

		if ( totalPages ) {
			arguments.logger?.info( "Total #totalPages# pages have been created." );
		} else {
			arguments.logger?.warn( "No pages have been created." );
		}

		arguments.logger?.info( "Done." );

		return parentPageId;
	}

	private string function _unpackZipFile( required string zipFilePath ) {
		var tmpDir = ExpandPath( "/uploads/tmp/#CreateUUID()#" );

		DirectoryCreate( tmpDir, true, true );

		zip action="unzip" destination=tmpDir file=arguments.zipFilePath;

		return tmpDir;
	}

	private string function _getHtmlContent( required string htmlFileDir ) {
		var htmlFiles = DirectoryList( arguments.htmlFileDir, false, "path", "*.html" );

		if ( ArrayLen( htmlFiles ) == 1 ) {
			return Trim( FileRead( htmlFiles[ 1 ] ) );
		}

		return "";
	}

	private numeric function _processPages(
		  required array   pages
		, required string  htmlFileDir
		, required string  parentPageId
		,          string  childPagesType          = "standard_page"
		,          boolean mainContentEditDisabled = false
		,          any     logger
		,          any     progress
	) {
		var totalPages = ArrayLen( arguments.pages );

		if ( totalPages ) {
			var parentPage = siteTreeService.getPage( id=arguments.parentPageId );

			for ( var page in pages ) {
				var slug = $helpers.slugify( page.title );

				var content = _processImages( argumentCollection=arguments, htmlContent=page.content );

				if ( page.child ) {
					var pageId = siteTreeService.getPageIdBySlug( slug="#parentPage._hierarchy_slug##slug#/" );

					if ( !$helpers.isEmptyString( pageId ) ) {
						arguments.logger?.info( "Updating #arguments.childPagesType#: #page.title#" );

						siteTreeService.editPage(
							  id                         = pageId
							, title                      = page.title
							, main_content               = content
							, main_content_edit_disabled = arguments.mainContentEditDisabled
						);
					} else {
						arguments.logger?.info( "Creating #arguments.childPagesType#: #page.title#" );

						pageId = siteTreeService.addPage(
							  page_type                  = arguments.childPagesType
							, slug                       = slug
							, parent_page                = parentPageId
							, title                      = page.title
							, main_content               = content
							, main_content_edit_disabled = arguments.mainContentEditDisabled
						);
					}
				} else {
					var pageTitle = $helpers.isEmptyString( page.title ) ? parentPage.title : page.title;

					arguments.logger?.info( "Updating #parentPage.page_type#: #pageTitle#" );

					siteTreeService.editPage(
						  id                         = parentPageId
						, title                      = pageTitle
						, main_content               = content
						, main_content_edit_disabled = arguments.mainContentEditDisabled
					);
				}
			}
		}

		return totalPages;
	}

	private string function _processImages(
		  required string htmlContent
		, required string htmlFileDir
		,          any    logger
		,          any    progress
	) {
		return dynamicFindAndReplaceService.dynamicFindAndReplace( source=arguments.htmlContent, regexPattern='<img[^>]*src="(.*?)"[^>]*>', recurse=false, processor=function( captureGroups ) {
			var srcPath = arguments.captureGroups[ 2 ] ?: "";

			if ( !$helpers.isEmptyString( srcPath ) ) {
				var fileName = ListLast( srcPath, "/" );
				var filePath = "#htmlFileDir#/#srcPath#";

				var assetId = assetManagerService.addAsset(
					  folder            = "importHtmlFiles"
					, ensureUniqueTitle = true
					, fileName          = fileName
					, filePath          = filePath
				);

				if ( !$helpers.isEmptyString( assetId ) ) {
					var configs = {
						asset = assetId
					};

					return "{{image:#UrlEncode( SerializeJSON( configs ) )#:image}}";
				}
			}

			return "";
		} );
	}

	private any function _new( className ) {
		return CreateObject( "java", arguments.className, _getLib() );
	}

	private array function _getLib() {
		if ( !ArrayLen( _lib ) ) {
			var libDir = ExpandPath( "/preside/system/services/email/lib" );

			_lib = DirectoryList( libDir, false, "path", "*.jar" );
		}
		return _lib;
	}

}