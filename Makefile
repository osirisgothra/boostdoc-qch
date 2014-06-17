# Copyright (C) 2013-2014 Gabriel T. Sharp
# 
# This file is part of boost qch help generator.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# makefile for generating lists

boost.qch : boost.qhp
	/usr/bin/qhelpgenerator boost.qhp -o boost.qch

boost.qhp : boost.qhpsrc files-unformatted.list sections.list
	./make-boost-qhp.sh

sections.list : files-unformatted.list
	./generatesections.sh

files-unformatted.list : index.htm
	./generatelists.sh


clean :	
	rm -fv boost.qch boost.qhp files.list files-unformatted.list sections.list
