component extends="coldbox.system.Interceptor" {

	property name="siteTreeService" inject="delayedInjector:SiteTreeService";
	property name="formsService"    inject="delayedInjector:FormsService";

	public void function configure() {}

	public void function preRenderForm( event, interceptData ) {
		interceptData.formName = interceptData.formName ?: ""

		if ( interceptData.formName == "preside-objects.page.edit" ) {
			var pageId = interceptData.savedData.page ?: "";

			var page = siteTreeService.getPage( id=pageId );

			if ( isTrue( page.main_content_edit_disabled ?: "" ) ) {
				interceptData.formName = formsService.createForm( basedOn=interceptData.formName, generator=function( formDefinition ) {
					formDefinition.modifyField(
						  name     = "main_content"
						, fieldset = "main"
						, tab      = "main"
						, toolbar  = "htmlImportReadOnly"
						, attribs  = { disabled="disabled" }
						, label    = translateResource( uri="HTMLImport:field.main_content.disabled.label" )
						, help     = translateResource( uri="HTMLImport:field.main_content.disabled.help" )
					);
				} );
			}
		}
	}

}
