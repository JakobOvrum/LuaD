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

var qualifiedModuleNameToUrl = function(modName) {
	return modName.slice(5).replace('.', '_') + '.html';
};

var treePackageNode = function(name) {
	return '<li class="module-tree-node dropdown">' +
	       '<a href="#"><i class="icon-th-list"></i> ' + name + '<b class="caret"></b></a>' +
		   '<ul></ul></li>';
};

var treeModuleNode = function(name, url) {
	return '<li>' +
	       '<a href="' + url + '"><i class="icon-th"></i> ' + name + '</a>' +
		   '</li>';
};

var populateModuleList = function(modlist) {
	var listHeader = $('#module-list');
	
	var root = buildModuleHierarchy(modlist);
	
	var traverser = function(node, parentList) {
		for(var name in node.members) {
			var member = node.members[name];
			
			if(member.type == 'package') {
				var elem = $(treePackageNode(name));
				parentList.append(elem);
				arguments.callee(member, elem.find('ul'));
				
			} else if(member.type == 'module') {
				var url = qualifiedModuleNameToUrl(member.qualifiedName);
				var elem = $(treeModuleNode(name, url));
				parentList.append(elem);
				
				if(member.qualifiedName == Title) {
					elem.find('a').append(' <i class="icon-asterisk"></i>');
				}
			}
		}
	};
	
	traverser(root, listHeader);
	
	var treeNodes = $('.module-tree-node');
	
	treeNodes.children('a').click(function() {
		$(this).parent().children('ul').toggle();
	});
	
	treeNodes.children('ul').hide();
};

var populateSymbolList = function(symbols) {
	var symbolHeader = $('#symbol-list');
	
	for(var i = 0; i < symbols.length; i++) {
		var symbol = symbols[i];
		var elem = '<li><a href="#' + symbol + '">' + symbol + '</a></li>';
		$(elem).insertAfter(symbolHeader);
	}
};

var updateBreadcrumb = function(qualifiedName) {
	var breadcrumb = $('#module-breadcrumb');
	
	var parts = qualifiedName.split('.');
	for(var i = 0; i < parts.length; i++) {
		var part = parts[i];
		
		if(i == parts.length - 1) {
			breadcrumb.append('<li class="active"><h2>' + part + '</h2></li>');
		} else {
			breadcrumb.append('<li><h2>' + part + '<span class="divider">/</span></h2></li>');
		}
	}
};

var gatherSymbols = function() {
	var list = new Array();
	$('.psymbol').each(function(index) {
		list.push($(this).html());
	});
	return list;
};

var setupGotoSymbolForm = function(symbols) {
	var form = $('#gotosymbol');
	var input = form.find('input');
	
	form.submit(function(event) {
		event.preventDefault();
		window.location.hash = input.val();
		input.val('');
		input.blur();
	});
	
	input.typeahead({
		'source': symbols
	});
};

$(document).ready(function() {
	updateBreadcrumb(Title);
	
	populateModuleList(Modules);

	var symbols = gatherSymbols();
	setupGotoSymbolForm(symbols);
	populateSymbolList(symbols);
});
