//
//  InitialDemoView.swift
//  Monolog
//
//  Created by Saaketh Chennaiahgari on 8/17/23.
//

import SwiftUI

struct InitialDemoView: View {
    var body: some View {
        VStack{
            HStack{
                Text("Welcome To Monolog").font(.title)
                Spacer()
            }
            HStack{
                Spacer()
                VStack{
                    Text("Record Anything")
                    Text("Monolog allows you ot record, just like voice memos")
                }
            }
        }.padding()
    }
}

struct InitialDemoView_Previews: PreviewProvider {
    static var previews: some View {
        InitialDemoView()
    }
}
