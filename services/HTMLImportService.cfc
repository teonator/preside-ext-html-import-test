/**
 * @presideService true
 * @singleton      true
 */
component {

	property name="siteTreeService" inject="SiteTreeService";

	variables._lib   = [];
	variables._jsoup = "";

	public any function init() {
		variables._jsoup = _new( "org.jsoup.Jsoup" );

		return this;
	}

	public string function importFromZipFile(
		  required struct  zipFile
		, required string  parentPage
		,          boolean mainContentEditDisabled = false
		,          string  pageHeading             = "h1"
		,          boolean childPagesEnabled       = false
		,          string  childPagesHeading       = "h2"
		,          boolean contentSectionsEnabled  = false
		,          string  contentSectionsHeading  = "h3"
		,          any     logger
		,          any     progress
	) {
		var tmpFileDir = "";
		var rootPageId = arguments.parentPage;

		try {
			if ( !$helpers.isEmptyString( arguments.zipFile.path ?: "" ) ) {
				arguments.logger?.info( "Unpacking ZIP..." );

				tmpFileDir  = _unpackZipFile( zipFilePath=arguments.zipFile.path );

				var htmlContent = _getHtmlContent( htmlFileDir=tmpFileDir );

				if ( !$helpers.isEmptyString( htmlContent ) ) {
					arguments.logger?.info( "Parsing HTML..." );

					var html  = variables._jsoup.parse( htmlContent );

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
								ArrayAppend( pages, { title=pageTitle, content=pageContent, root=pageRoot } );
							}

							pageTitle = tagText;
							pageContent  = "";
							pageRoot  = arguments.pageHeading == tagName;
						} else {
							pageContent &= element.toString();
						}
					}

					if ( !$helpers.isEmptyString( pageTitle ) || !$helpers.isEmptyString( pageContent ) ) {
						ArrayAppend( pages, { title=pageTitle, content=pageContent, root=pageRoot } );
					}

					if ( ArrayLen( pages ) ) {
						var parentPage = siteTreeService.getPage( id=rootPageId );

						for ( var page in pages ) {
							var slug = $helpers.slugify( page.title );

							var pageId = siteTreeService.getPageIdBySlug( slug="/#parentPage.slug#/#slug#/" );

							if ( !$helpers.isEmptyString( pageId ) ) {
								arguments.logger?.info( "Updating page: #slug#" );

								siteTreeService.editPage(
									  id           = pageId
									, parent_page  = rootPageId
									, title        = page.title
									, main_content = page.content
								);
							} else {
								arguments.logger?.info( "Creating page: #slug#" );

								pageId = siteTreeService.addPage(
									  page_type    = "standard_page"
									, slug         = slug
									, parent_page  = rootPageId
									, title        = page.title
									, main_content = page.content
								);
							}

							if ( page.root ) {
								rootPageId = pageId;
							}
						}
					}
				}
			}
		} catch( any e ) {
			rethrow;
		} finally {
			try {
				DirectoryDelete( zipDir, true );
			} catch( any e ){}
		}

		return rootPageId;
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