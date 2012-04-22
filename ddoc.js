/**
 * Build a table representing the module hierarchy of the project
 * given a linear list of modules.
 */
var buildModuleHierarchy = function(modlist) {
	var root = {'members': {}};
	
	for (var i = 0; i < modlist.length; i++) {
		var qualifiedName = modlist[i];
		var parts = qualifiedName.split('.');
		
		var parent = root;
		for(var partIndex = 0; partIndex < parts.length; partIndex++) {
			var name = parts[partIndex];
			var node;
			
			if(partIndex == parts.length - 1) {
				node = {'type': 'module', 'qualifiedName': qualifiedName};
				parent.members[name] = node;
			} else {
				node = parent.members[name];
				if(typeof node == "undefined") {
					node = {'type': 'package', 'members': {}};
					parent.members[name] = node;
				}
			}
			
			parent = node;
		}
	}
	
	return root;
};

/**
 * Build a path to the appropriate resource for a fully qualified module name.
 */
var qualifiedModuleNameToUrl = function(modName) {
	return modName.slice(modName.indexOf(".") + 1).replace('.', '_') + '.html';
};

/**
 * Build a package node for the module tree given the name of the package.
 */
var treePackageNode = function(name) {
	return '<li class="module-tree-node dropdown">' +
	       '<a href="#"><i class="icon-th-list"></i> ' + name + '<b class="caret"></b></a>' +
		   '<ul></ul></li>';
};

/**
 * Build a module node for the module tree given the name of the module
 * and a URL to the associated resource.
 */
var treeModuleNode = function(name, url) {
	return '<li>' +
	       '<a href="' + url + '"><i class="icon-th"></i> ' + name + '</a>' +
		   '</li>';
};

/**
 * Create the module tree in the sidebar.
 */
var populateModuleList = function(modlist) {
	var $listHeader = $('#module-list');
	
	var root = buildModuleHierarchy(modlist);
	
	var traverser = function(node, parentList) {
		for(var name in node.members) {
			var member = node.members[name];
			
			if(member.type == 'package') {
				var $elem = $(treePackageNode(name));
				parentList.append($elem);
				arguments.callee(member, $elem.find('ul'));
				
			} else if(member.type == 'module') {
				var url = qualifiedModuleNameToUrl(member.qualifiedName);
				var $elem = $(treeModuleNode(name, url));
				parentList.append($elem);
				
				if(member.qualifiedName == Title) { // Current module.
					$elem.find('a').append(' <i class="icon-asterisk"></i>');
				}
			}
		}
	};
	
	traverser(root, $listHeader);
	
	var $treeNodes = $('.module-tree-node');
	
	$treeNodes.children('a').click(function() {
		$(this).parent().children('ul').toggle();
	});
};

/**
 * Create the symbol list in the sidebar.
 */
var populateSymbolList = function(symbols) {
	if(symbols.length == 0) { // Do not show the symbol list header on pages with no symbols.
		return;
	}
	
	var $symbolHeader = $('#symbol-list');
	
	$symbolHeader.removeClass('hidden');
	
	var $prev = $symbolHeader;
	for(var i = 0; i < symbols.length; i++) {
		var symbol = symbols[i];
		var $elem = $('<li><a href="#' + symbol + '">' + symbol + '</a></li>');
		$elem.insertAfter($prev);
		$prev = $elem;
	}
};

/**
 * Build a relative path for the given module name.
 */
 var moduleNameToPath = function(modName) {
	return modName.replace(/\./g, '/') + '.d';
 };

/**
 * Configure the breadcrumb component at the top of the page
 * with the current module.
 */
var updateBreadcrumb = function(qualifiedName, sourceRepoUrl) {
	var $breadcrumb = $('#module-breadcrumb');
	
	var parts = qualifiedName.split('.');
	for(var i = 0; i < parts.length; i++) {
		var part = parts[i];
		
		if(i == parts.length - 1) {
			var sourceUrl = sourceRepoUrl + '/' + moduleNameToPath(qualifiedName);
			$breadcrumb.append('<li class="active"><h2>' + part + ' <a href="' + sourceUrl + '"><small>view source</small></a></h2></li>');
		} else {
			$breadcrumb.append('<li><h2>' + part + '<span class="divider">/</span></h2></li>');
		}
	}
};

var gatherSymbols = function() {
	var list = new Array();
	$('.psymbol').each(function() {
		list.push($(this).html());
	});
	return list;
};

/**
 * Configure the goto-symbol search form in the titlebar.
 */
var setupGotoSymbolForm = function(symbols) {
	if(symbols.length == 0) { // Do not show the goto-symbol form on pages with no symbols.
		return;
	}
	
	var $form = $('#gotosymbol');
	var $input = $form.children('input');
	
	$form.submit(function(event) {
		event.preventDefault();
		window.location.hash = $input.val();
		$input.val('');
		$input.blur();
	});
	
	$input.typeahead({
		'source': symbols
	});
	
	$form.removeClass('hidden');
};

// 'Title', 'SourceRepository', and 'Modules' are created inline in the DDoc generated HTML page.
$(document).ready(function() {
	updateBreadcrumb(Title, SourceRepository);
	
	populateModuleList(Modules);

	var symbols = gatherSymbols();
	setupGotoSymbolForm(symbols);
	populateSymbolList(symbols);
});
