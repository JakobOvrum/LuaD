import luad.all;

import std.stdio;

struct Contact
{
	string forename, surname;
	string email;
	uint number;

	static Contact[] fromFile(in char[] path)
	{
		auto lua = new LuaState;
		Contact[] contacts;

		lua["Contact"] = (Contact c)
		{
			contacts ~= c;
		};

		lua.doFile(path);

		return contacts;
	}
}

void main()
{
	Contact[] phonebook = Contact.fromFile("contacts.lua");
	foreach(contact; phonebook)
	{
		writefln("%s, %s - %s (%s)", contact.surname, contact.forename,
			contact.number, contact.email);
	}
}
