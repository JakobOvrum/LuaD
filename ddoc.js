/**
 * Build a table representing the module hierarchy of the project
 * given a linear list of modules.
 */
function buildModuleHierarchy(modlist) {
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
function qualifiedModuleNameToUrl(modName) {
	return modName.slice(modName.indexOf(".") + 1).replace('.', '_') + '.html';
};

/**
 * Build a package node for the module tree given the name of the package.
 */
function treePackageNode(name) {
	return '<li class="dropdown">' +
	       '<a class="tree-node" href="javascript:;"><i class="icon-th-list"></i> ' + name + '<b class="caret"></b></a>' +
		   '<ul class="custom-icon-list"></ul></li>';
};

/**
 * Build a module node for the module tree given the name of the module
 * and a URL to the associated resource.
 */
function treeModuleNode(name, url) {
	return '<li>' +
	       '<a class="tree-leaf" href="' + url + '"><i class="icon-th"></i> ' + name + '</a>' +
		   '</li>';
};

/**
 * Create the module tree in the sidebar.
 */
function populateModuleList(modlist) {
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
};

/**
 * Build a relative path for the given module name.
 */
function moduleNameToPath(modName) {
	return modName.replace(/\./g, '/') + '.d';
};

/**
 * Configure the breadcrumb component at the top of the page
 * with the current module.
 */
function updateBreadcrumb(qualifiedName, sourceRepoUrl) {
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

var enumRegex = /^enum /;
var structRegex = /^struct /;
var classRegex = /^class /;
var templateRegex = /^template /;
var functionRegex = /\);\s*$/m;

function buildSymbolTree() {
	function fillTree(parentNode, $parent) {
		$parent.children('.declaration').each(function() {
			var $decl = $(this);
			var text = $decl.text();
			
			var $symbol = $decl.find('.psymbol');
			var symbol = $symbol.html();
			
			function fillSubTree(type) {
				var subTree = {
					'name': symbol,
					'type': type,
					'decl': text,
					'members': new Array()
				};
				
				parentNode.push(subTree);
				fillTree(subTree.members, $decl.next('.decldd').children('.member-list'));
			}
			
			function addLeaf(type) {
				var leaf = {
					'name': symbol,
					'type': type,
					'decl': text
				};
				
				parentNode.push(leaf);
			}
			
			if(enumRegex.test(text)) {
				fillSubTree('enum');
			} else if(structRegex.test(text)) {
				fillSubTree('struct');
			} else if(classRegex.test(text)) {
				fillSubTree('class');
			} else if(templateRegex.test(text)) {
				fillSubTree('template');
			} else if(functionRegex.test(text)) {
				addLeaf('function');
			} else {
				addLeaf('variable');
			}
		});
	}
	
	var $declRoot = $('#declaration-list');
	var tree = new Array();
	
	fillTree(tree, $declRoot);
	
	return tree;
}

/**
 * Create the symbol list in the sidebar.
 */
function populateSymbolList(tree) {
	if(tree.length == 0) { // Do not show the symbol list header on pages with no symbols.
		return;
	}
	
	var $symbolHeader = $('#symbol-list');
	$symbolHeader.removeClass('hidden');
	
	function expandableNode(name, type) {
		return '<li class="dropdown"><span>' +
		       '<i class="ddoc-icon-' + type + '"></i><a href="#' + name + '">' + name + '</a>' +
		       '</span><ul class="custom-icon-list"></ul></li>';
	}
	
	function leafNode(name, type) {
		return '<li><span><i class="ddoc-icon-' + type + '"></i><a href="#' + name + '">' + name + '</a></span></li>';
	}
	
	(function(parent, $parent) {
		for(var i = 0; i < parent.length; i++) {
			var node = parent[i];
			var isTree = typeof node.members !== 'undefined';
			
			if(isTree) {
				var $node = $(expandableNode(node.name, node.type));
				$parent.append($node);
				
				if(node.members.length > 0) {
					var $caret = $('<b class="caret tree-node-standalone"></b>');
					$node.find('span').append($caret);
				}
				
				var $list = $node.find('ul');
				arguments.callee(node.members, $list);
			} else {
				var $node = $(leafNode(node.name, node.type));
				$parent.append($node);
			}
		}
	})(tree, $symbolHeader.parent());
};

function buildDeclArray(tree) {
	return tree;
}

/**
 * Configure the goto-symbol search form in the titlebar.
 */
function setupGotoSymbolForm(symbolTree) {
	if(symbolTree.length == 0) { // Do not show the goto-symbol form on pages with no symbols.
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
		'source': buildDeclArray(symbolTree)
	});
	
	$form.removeClass('hidden');
}

// 'Title', 'SourceRepository', and 'Modules' are created inline in the DDoc generated HTML page.
$(document).ready(function() {
	updateBreadcrumb(Title, SourceRepository);
	
	populateModuleList(Modules);

	//var symbols = gatherSymbols();
	//setupGotoSymbolForm(symbols);
	//populateSymbolList(symbols);
	
	var symbolTree = buildSymbolTree();
	populateSymbolList(symbolTree);
	//alert(JSON.stringify(symbolTree, null, 4));
	
	function treeNodeClick() {
		$(this).parent().children('ul').toggle();
	}
	
	function standaloneNodeClick() {
		$(this).parent().parent().children('ul').toggle();
	}
	
	var $treeNodes = $('.tree-node');
	var $standaloneTreeNodes = $('.tree-node-standalone');
	
	$treeNodes.click(treeNodeClick);
	$standaloneTreeNodes.click(standaloneNodeClick);
});
