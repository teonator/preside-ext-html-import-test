component {

	public void function configure( required struct config ) {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		_setupEnums( settings );
	}

	private void function _setupEnums( settings ) {
		settings.enum.htmlImportPageHeading            = [ "h1", "h2", "h3", "h4", "h5", "h6" ];
		settings.enum.htmlImportChildPagesHeading      = [ "h1", "h2", "h3", "h4", "h5", "h6" ];
		settings.enum.htmlImportContentSectionsHeading = [ "h1", "h2", "h3", "h4", "h5", "h6" ];
	}

}
