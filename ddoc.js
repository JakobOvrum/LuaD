/**
 * Build a table representing the module hierarchy of the project
 * given a linear list of modules.
 */
function buildModuleTree(modlist) {
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
 * Create the module list in the sidebar.
 */
function populateModuleList(modTree) {	
	function treePackageNode(name) {
		return '<li class="dropdown">' +
			   '<a class="tree-node" href="javascript:;"><i class="icon-th-list"></i> ' + name + '<b class="caret"></b></a>' +
			   '<ul class="custom-icon-list"></ul></li>';
	}

	function treeModuleNode(name, url) {
		return '<li>' +
			   '<a class="tree-leaf" href="' + url + '"><i class="icon-th"></i> ' + name + '</a>' +
			   '</li>';
	}
	
	function traverser(node, parentList) {
		for(var name in node.members) {
			var member = node.members[name];
			
			if(member.type == 'package') {
				var $elem = $(treePackageNode(name));
				parentList.append($elem);
				traverser(member, $elem.find('ul'));
				
			} else if(member.type == 'module') {
				var url = qualifiedModuleNameToUrl(member.qualifiedName);
				var $elem = $(treeModuleNode(name, url));
				parentList.append($elem);
				
				if(member.qualifiedName == Title) { // Current module.
					$elem.find('a').append(' <i class="icon-asterisk"></i>');
				}
			}
		}
	}
	
	var $listHeader = $('#module-list');
	traverser(modTree, $listHeader);
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
var propertyRegex = /@property/m;
var specialMemberRegex = /^([^(]+)/;

/**
 * Build a table out of all symbols declared in the current module.
 */
function buildSymbolTree() {
	function fillTree(parentNode, $parent) {
		$parent.children('.declaration').each(function() {
			var $decl = $(this);
			var text = $decl.text();
			
			var $symbol = $decl.find('.symbol');
			var symbol;
			if($symbol.length == 0) { // Special member (e.g. constructor).
				symbol = text.match(specialMemberRegex)[0];
			} else {
				symbol = $symbol.html();
			}
			
			function fillSubTree(type) {
				var subTree = {
					'name': symbol,
					'type': type,
					'members': new Array(),
					'decl': $decl,
					'symbolNode': $symbol
				};
				
				parentNode.push(subTree);
				fillTree(subTree.members, $decl.next('.declaration-content').children('.member-list'));
			}
			
			function addLeaf(type) {
				var leaf = {
					'name': symbol,
					'type': type,
					'decl': $decl,
					'symbolNode': $symbol
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
				if(propertyRegex.test(text)) {
					addLeaf('property');
				} else {
					addLeaf('function');
				}
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
 * Returns an array of the anchor names for the symbols in the list.
 */
function populateSymbolList(tree) {	
	function expandableNode(name, anchor, type) {
		return '<li class="dropdown"><span>' +
		       '<i class="ddoc-icon-' + type + '"></i><a class="symbol-anchor" href="#' + anchor + '">' + name + '</a>' +
		       '</span><ul class="custom-icon-list"></ul></li>';
	}
	
	function leafNode(name, anchor, type) {
		return '<li><span><i class="ddoc-icon-' + type + '"></i><a class="symbol-anchor" href="#' + anchor + '">' + name + '</a></span></li>';
	}
	
	var anchorNames = new Array();
	
	function traverser(parent, $parent, anchorTail) {
		for(var i = 0; i < parent.length; i++) {
			var node = parent[i];
			var isTree = typeof node.members !== 'undefined';
			var anchorName = anchorTail + node.name;
			anchorNames.push(anchorName);
			
			node.symbolNode.attr('id', anchorName);
			node.symbolNode.attr('href', '#' + anchorName);
			
			if(isTree) {
				var $node = $(expandableNode(node.name, anchorName, node.type));
				$parent.append($node);
				
				if(node.members.length > 0) {
					var $caret = $('<b class="caret tree-node-standalone"></b>');
					$node.find('span').append($caret);
				}
				
				var $list = $node.find('ul');
				traverser(node.members, $list, anchorName + '.');
			} else {
				var $node = $(leafNode(node.name, anchorName, node.type));
				$parent.append($node);
			}
		}
	}
	
	var $symbolHeader = $('#symbol-list');
	$symbolHeader.removeClass('hidden');
	
	traverser(tree, $symbolHeader.parent(), '');
	
	return anchorNames;
};

/**
 * Set the current symbol to highlight.
 */
function highlightSymbol(targetId) {
	var escapedTargetId = targetId.replace(/\./g, '\\.');
	var $target = $(escapedTargetId).parent();
	
	$target.addClass('highlighted-symbol');
	
	if(window.currentlyHighlightedSymbol) {
		window.currentlyHighlightedSymbol.removeClass('highlighted-symbol');
	}
	
	window.currentlyHighlightedSymbol = $target;
}

/**
 * Configure the goto-symbol search form in the titlebar.
 */
function setupGotoSymbolForm(typeaheadData) {
	var $form = $('#gotosymbol');
	var $input = $form.children('input');
	
	$form.submit(function(event) {
		event.preventDefault();
		
		window.location.hash = $input.val();
		highlightSymbol('#' + $input.val());
		
		$input.val('');
		$input.blur();
	});
	
	$input.typeahead({ 'source': typeaheadData });
	
	$form.removeClass('hidden');
}

// 'Title', 'SourceRepository', and 'Modules' are created inline in the DDoc generated HTML page.
$(document).ready(function() {
	// Setup page title.
	updateBreadcrumb(Title, SourceRepository);
	
	// Construct module list.
	populateModuleList(buildModuleTree(Modules));
	
	// Construct symbol list and setup goto-symbol form.
	var symbolTree = buildSymbolTree();
	if(symbolTree.length > 0) {
		var symbolAnchors = populateSymbolList(symbolTree);
		setupGotoSymbolForm(symbolAnchors);
	}
	
	// Setup symbol anchor highlighting.
	$('.symbol-anchor').click(function() {
		var targetId = $(this).attr('href');
		highlightSymbol(targetId);
	});
	
	if(document.location.hash.length > 0) {
		highlightSymbol(document.location.hash);
	}
	
	// Setup collapsable tree nodes.
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
